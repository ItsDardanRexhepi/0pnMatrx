// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title RoyaltyNFT
/// @author 0pnMatrx — Creator Economy Pack
/// @notice ERC-721 NFT collection with EIP-2981 royalties enforced on every transfer.
///         Supports configurable per-token and default royalties, metadata reveals,
///         mint phases (allowlist + public), and operator filtering.
/// @dev Features:
///      - EIP-2981 royalty standard (compatible with OpenSea, Blur, etc.)
///      - Configurable default royalty + per-token overrides
///      - Allowlist minting with Merkle proof verification
///      - Public mint with configurable price and supply cap
///      - Metadata reveal mechanism
///      - Owner can update royalty info at any time

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RoyaltyNFT is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC2981,
    Ownable,
    ReentrancyGuard
{
    using Strings for uint256;

    // ── State ────────────────────────────────────────────────────────

    uint256 public maxSupply;
    uint256 public mintPrice;
    uint256 public maxPerWallet;
    uint256 private _nextTokenId;

    string private _baseTokenURI;
    string private _preRevealURI;
    bool public revealed;

    /// @notice Merkle root for allowlist minting
    bytes32 public merkleRoot;

    /// @notice Mint phase control
    bool public allowlistMintActive;
    bool public publicMintActive;

    /// @notice Track mints per wallet
    mapping(address => uint256) public mintCount;

    // ── Events ───────────────────────────────────────────────────────
    event Minted(address indexed to, uint256 indexed tokenId);
    event BatchMinted(address indexed to, uint256 startId, uint256 count);
    event MetadataRevealed(string baseURI);
    event MintPhaseUpdated(bool allowlist, bool public_);
    event RoyaltyUpdated(address receiver, uint96 feeBps);
    event Withdrawn(address indexed to, uint256 amount);

    // ── Constructor ──────────────────────────────────────────────────

    /// @param name_ Collection name
    /// @param symbol_ Collection symbol
    /// @param maxSupply_ Maximum number of tokens
    /// @param mintPrice_ Price per mint in wei
    /// @param maxPerWallet_ Maximum mints per wallet (0 = unlimited)
    /// @param royaltyReceiver Default royalty receiver address
    /// @param royaltyBps Default royalty in basis points (e.g., 500 = 5%)
    /// @param preRevealURI_ URI shown before reveal
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        uint256 maxPerWallet_,
        address royaltyReceiver,
        uint96 royaltyBps,
        string memory preRevealURI_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
        maxPerWallet = maxPerWallet_;
        _preRevealURI = preRevealURI_;
        _setDefaultRoyalty(royaltyReceiver, royaltyBps);
    }

    // ── Minting ──────────────────────────────────────────────────────

    /// @notice Allowlist mint with Merkle proof
    /// @param proof Merkle proof for the caller's address
    /// @param quantity Number of tokens to mint
    function allowlistMint(bytes32[] calldata proof, uint256 quantity)
        external
        payable
        nonReentrant
    {
        require(allowlistMintActive, "Allowlist mint not active");
        require(
            MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender))),
            "Invalid proof"
        );
        _mintTokens(msg.sender, quantity);
    }

    /// @notice Public mint
    /// @param quantity Number of tokens to mint
    function publicMint(uint256 quantity) external payable nonReentrant {
        require(publicMintActive, "Public mint not active");
        _mintTokens(msg.sender, quantity);
    }

    /// @notice Owner mint (free, no restrictions)
    /// @param to Recipient address
    /// @param quantity Number of tokens to mint
    function ownerMint(address to, uint256 quantity) external onlyOwner {
        require(_nextTokenId + quantity <= maxSupply, "Exceeds supply");
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(to, tokenId);
            emit Minted(to, tokenId);
        }
        emit BatchMinted(to, _nextTokenId - quantity, quantity);
    }

    // ── Metadata ─────────────────────────────────────────────────────

    /// @notice Reveal metadata by setting the base URI
    /// @param baseURI_ The new base URI for metadata
    function reveal(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        revealed = true;
        emit MetadataRevealed(baseURI_);
    }

    /// @notice Update the pre-reveal URI
    function setPreRevealURI(string calldata uri) external onlyOwner {
        _preRevealURI = uri;
    }

    // ── Royalties ────────────────────────────────────────────────────

    /// @notice Update default royalty for all tokens
    /// @param receiver The royalty receiver
    /// @param feeBps Royalty in basis points (max 10000)
    function setDefaultRoyalty(address receiver, uint96 feeBps) external onlyOwner {
        _setDefaultRoyalty(receiver, feeBps);
        emit RoyaltyUpdated(receiver, feeBps);
    }

    /// @notice Set a specific royalty for a single token
    /// @param tokenId The token ID
    /// @param receiver The royalty receiver for this token
    /// @param feeBps Royalty in basis points
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeBps)
        external
        onlyOwner
    {
        _setTokenRoyalty(tokenId, receiver, feeBps);
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Toggle mint phases
    function setMintPhases(bool allowlist, bool public_) external onlyOwner {
        allowlistMintActive = allowlist;
        publicMintActive = public_;
        emit MintPhaseUpdated(allowlist, public_);
    }

    /// @notice Set the Merkle root for allowlist verification
    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
    }

    /// @notice Update mint price
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    /// @notice Update max per wallet
    function setMaxPerWallet(uint256 newMax) external onlyOwner {
        maxPerWallet = newMax;
    }

    /// @notice Withdraw contract balance
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
        emit Withdrawn(owner(), balance);
    }

    // ── View ─────────────────────────────────────────────────────────

    /// @notice Get the total number of minted tokens
    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Get remaining mintable supply
    function remainingSupply() external view returns (uint256) {
        return maxSupply - _nextTokenId;
    }

    // ── Overrides ────────────────────────────────────────────────────

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        _requireOwned(tokenId);

        if (!revealed) {
            return _preRevealURI;
        }

        return string(abi.encodePacked(_baseTokenURI, tokenId.toString(), ".json"));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _mintTokens(address to, uint256 quantity) internal {
        require(quantity > 0, "Zero quantity");
        require(_nextTokenId + quantity <= maxSupply, "Exceeds supply");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        if (maxPerWallet > 0) {
            require(mintCount[to] + quantity <= maxPerWallet, "Exceeds wallet limit");
        }

        mintCount[to] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(to, tokenId);
            emit Minted(to, tokenId);
        }

        // Refund overpayment
        uint256 cost = mintPrice * quantity;
        if (msg.value > cost) {
            (bool success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }
    }
}
