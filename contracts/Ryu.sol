// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./lib/ERC2981PerTokenRoyalties.sol";

contract Ryu is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    ERC2981PerTokenRoyalties
{
    using Strings for uint256;

    uint256 public constant MAX_MINTABLE = 3333;
    uint256 public constant MAX_PER_CLAIM = 10;
    uint256 public constant NFT_PRICE = 0.01 ether;
    uint256 public constant ROYALTY_VALUE = 300;

    // tokenID mapping
    mapping(uint256 => uint256) indexer;

    uint256 indexerLength;
    mapping(uint256 => uint256) tokenIDMap;
    mapping(uint256 => uint256) takenImages;
    mapping(address => uint256) earlyMinter;

    string baseUri;
    uint256 public minted;
    bool public canClaim;
    bool public earlyClaim;
    uint256 gross;
    address withdrawAddress;
    address royaltyAddress;

    event Claim(uint256 indexed _id);

    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() initializer {}

    function initialize(address _owner, address _royaltyAddress)
        public
        initializer
    {
        __ERC721_init("Ryu NFTs", "RYU");
        __ERC721Enumerable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        baseUri = "ipfs://QmUQMQhyqTMd5sAaT2ckZcpXDqAqotKiwJcPUnibjseFrK/";
        indexerLength = MAX_MINTABLE;
        minted = 0;
        canClaim = false;
        earlyClaim = false;
        gross = 0;

        withdrawAddress = _owner;
        royaltyAddress = _royaltyAddress;
    }

    function isEarlyMinter(address _address) public view returns (uint256) {
        return earlyMinter[_address];
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function getInterfaceID_IERC721() public pure returns (bytes4) {
        return type(IERC721Upgradeable).interfaceId;
    }

    function getInterfaceID_Metadata() public pure returns (bytes4) {
        return type(IERC721MetadataUpgradeable).interfaceId;
    }

    /* *************** */
    /*     Minting     */
    /* *************** */

    // Think of it as an array of 100 elements, where we take
    //    a random index, and then we want to make sure we don't
    //    pick it again.
    // If it hasn't been picked, the mapping points to 0, otherwise
    //    it will point to the index which took its place
    function getNextImageID(uint256 index) internal returns (uint256) {
        uint256 nextImageID = indexer[index];

        // if it's 0, means it hasn't been picked yet
        if (nextImageID == 0) {
            nextImageID = index;
        }
        // Swap last one with the picked one.
        // Last one can be a previously picked one as well, thats why we check
        if (indexer[indexerLength - 1] == 0) {
            indexer[index] = indexerLength - 1;
        } else {
            indexer[index] = indexer[indexerLength - 1];
        }
        indexerLength -= 1;
        return nextImageID;
    }

    function enoughRandom() internal view returns (uint256) {
        if (MAX_MINTABLE - minted == 0) return 0;
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        msg.sender,
                        blockhash(block.number)
                    )
                )
            ) % (indexerLength);
    }

    function randomMint(address receiver, uint256 nextTokenIndex) internal {
        uint256 nextIndexerId = enoughRandom();
        uint256 nextImageID = getNextImageID(nextIndexerId);

        assert(takenImages[nextImageID] == 0);
        takenImages[nextImageID] = 1;
        tokenIDMap[nextTokenIndex] = nextImageID;
        _safeMint(receiver, nextTokenIndex);
    }

    function toggleClaimability() external onlyOwner {
        canClaim = !canClaim;
    }

    function toggleEarlyClaimability() external onlyOwner {
        earlyClaim = !earlyClaim;
    }

    function earlyMint(uint256 n) public payable {
        require(earlyClaim, "It's not possible to claim just yet.");
        require(n + minted <= MAX_MINTABLE, "Not enough left to mint.");
        require(n > 0, "Number need to be higher than 0");
        require((earlyMinter[msg.sender] + n) <= 5, "Max per claim is 5");
        require(
            msg.value >= (NFT_PRICE * n),
            "Ether value sent is below the price"
        );

        earlyMinter[msg.sender] += n;

        uint256 total_cost = (NFT_PRICE * n);
        gross += total_cost;

        uint256 excess = msg.value - total_cost;
        payable(address(this)).transfer(total_cost);

        for (uint256 i = 0; i < n; i++) {
            randomMint(_msgSender(), minted);
            _setTokenRoyalty(minted, royaltyAddress, ROYALTY_VALUE);

            minted += 1;
            emit Claim(minted);
        }

        if (excess > 0) {
            payable(_msgSender()).transfer(excess);
        }
    }

    // //@dev this should be delted since this is just for test.
    // function freeMint(uint256 n) public {
    //     for (uint256 i = 0; i < n; i++) {
    //         randomMint(_msgSender(), minted);
    //         _setTokenRoyalty(minted, royaltyAddress, ROYALTY_VALUE);

    //         minted += 1;
    //         emit Claim(minted);
    //     }
    // }

    function claim(uint256 n) public payable {
        require(canClaim, "It's not possible to claim just yet.");
        require(n + minted <= MAX_MINTABLE, "Not enough left to mint.");
        require(n > 0, "Number need to be higher than 0");
        require(n <= MAX_PER_CLAIM, "Max per claim is 10");
        require(
            msg.value >= (NFT_PRICE * n),
            "Ether value sent is below the price"
        );

        uint256 total_cost = (NFT_PRICE * n);
        gross += total_cost;

        uint256 excess = msg.value - total_cost;
        payable(address(this)).transfer(total_cost);

        for (uint256 i = 0; i < n; i++) {
            randomMint(_msgSender(), minted);
            _setTokenRoyalty(minted, royaltyAddress, ROYALTY_VALUE);

            minted += 1;
            emit Claim(minted);
        }

        if (excess > 0) {
            payable(_msgSender()).transfer(excess);
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _safeTransfer(from, to, tokenId, _data);
    }

    /* ****************** */
    /*       ERC721       */
    /* ****************** */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory baseURI = _baseURI();
        uint256 imageID = tokenIDMap[tokenId];
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, imageID.toString(), ".json"))
                : "";
    }

    function setBaseUri(string memory uri) external onlyOwner {
        baseUri = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC2981Base, ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        bytes4 _INTERFACE_ID_ERC721 = 0x80ac58cd;
        bytes4 _INTERFACE_ID_METADATA = 0x5b5e139f;
        bytes4 _INTERFACE_ID_ERC2981 = 0x2a55205a;

        return (interfaceId == _INTERFACE_ID_ERC2981 ||
            interfaceId == _INTERFACE_ID_ERC721 ||
            interfaceId == _INTERFACE_ID_METADATA);
    }

    function setWithdrawAddress(address _withdrawAddress) external onlyOwner {
        withdrawAddress = _withdrawAddress;
    }

    function setRoyaltyAddress(address _royaltyAddress) external onlyOwner {
        royaltyAddress = _royaltyAddress;
    }

    function getWithdrawAddress() external view returns (address) {
        return withdrawAddress;
    }

    function getRoyaltyAddress() external view returns (address) {
        return royaltyAddress;
    }

    function withdraw() external {
        require(withdrawAddress == msg.sender, "Your are not the owner");
        require(address(this).balance > 0, "Nothing to withdraw");
        payable(_msgSender()).transfer(address(this).balance);
    }

    receive() external payable {}

    fallback() external payable {}
}
