// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "hardhat/console.sol";

interface INFT {
    function isLegend(uint256 nftId) external view returns (bool);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;
}

interface IRyuToken {
    function mint(address _to, uint256 _amount) external;

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

contract RyuNFTStaking is Ownable, IERC721Receiver {
    using SafeMath for uint256;

    INFT public nft;
    IRyuToken public ryuToken;

    uint256 public constant YIELD_CPS = 1; // tokens created per nft weight per second
    uint256 public constant CLAIM_TOKEN_TAX_PERCENTAGE = 199; // 1.9%
    uint256 public constant UNSTAKE_COOLDOWN_DURATION = 1 days; // 1 Day cooldown
    uint256 public constant LEGEND_REWARD_PER_DAY = 96860000000000000000; // 1 Day reward
    uint256 public constant BASE_REWARD_PER_DAY = 36570000000000000000; // 1 Day reward

    address private ADDR1 = 0xdFA0a7d220A506F2c5fF52bf308091cDe236aDeb;
    address private ADDR2 = 0xCF22147B74ce4Bb79D03dbD68b106529F5c3751E;

    struct StakeDetails {
        address owner;
        uint256 tokenId;
        bool isLegend;
        uint256 startTimestamp;
        bool staked;
    }

    struct OwnedStakeInfo {
        uint256 tokenId;
        uint256 rewardPerday;
        uint256 accrual;
        string tokenURI;
    }

    mapping(uint256 => StakeDetails) public stakes;

    struct UnstakeCooldown {
        address owner;
        uint256 tokenId;
        uint256 startTimestamp;
        bool present;
    }

    struct OwnedCooldownInfo {
        uint256 tokenId;
        uint256 startTimestamp;
    }

    mapping(uint256 => UnstakeCooldown) public unstakeCooldowns;

    mapping(address => mapping(uint256 => uint256)) private ownedStakes; // (user, index) => stake
    mapping(uint256 => uint256) private ownedStakesIndex; // token id => index in its owner's stake list
    mapping(address => uint256) public ownedStakesBalance; // user => stake count

    mapping(address => mapping(uint256 => uint256)) private ownedCooldowns; // (user, index) => cooldown
    mapping(uint256 => uint256) private ownedCooldownsIndex; // token id => index in its owner's cooldown list
    mapping(address => uint256) public ownedCooldownsBalance; // user => cooldown count

    /**
     * @dev If staking is paused or not.
     */
    bool public isPaused = true;

    constructor(INFT _nft, IRyuToken _ryuToken) {
        nft = _nft;
        ryuToken = _ryuToken;
    }

    /* View */
    function getTokensAccruedForMany(uint256[] calldata _tokenIds)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory tokenAmounts = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenAmounts[i] = _getTokensAccruedFor(_tokenIds[i], false);
        }
        return tokenAmounts;
    }

    function _getTokensAccruedFor(uint256 _tokenId, bool checkOwnership)
        internal
        view
        returns (uint256)
    {
        StakeDetails memory stake = stakes[_tokenId];
        require(stake.staked, "This token isn't staked");
        if (checkOwnership) {
            require(stake.owner == _msgSender(), "You don't own this token");
        }
        uint256 stakedDays = (block.timestamp - stake.startTimestamp) / 1 days;
        return stakedDays * getDayReward(_tokenId);
    }

    /* Mutators */

    function batchStake(uint256[] calldata _tokenIds) external {
        require(!isPaused, "Staking is not active.");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(
                nft.ownerOf(tokenId) == _msgSender(),
                "You don't own this token"
            );
            nft.safeTransferFrom(_msgSender(), address(this), tokenId);
            _addNftToStaking(tokenId, _msgSender());
        }
    }

    function stake(uint256 tokenId) public {
        require(!isPaused, "Staking is not active.");
        require(
            nft.ownerOf(tokenId) == _msgSender(),
            "You don't own this token"
        );
        nft.safeTransferFrom(_msgSender(), address(this), tokenId);
        _addNftToStaking(tokenId, _msgSender());
    }

    function stakeAll() external {
        OwnedStakeInfo[] memory unstakes = getUnstakedNftsOfOwner(_msgSender());
        for (uint256 i = 0; i < unstakes.length; i++) {
            uint256 tokenId = unstakes[i].tokenId;
            stake(tokenId);
        }
    }

    function claim(uint256 tokenId, bool _unstake) external {
        uint256 totalClaimed = 0;
        uint256 totalTaxed = 0;

        uint256 tokens = _getTokensAccruedFor(tokenId, true); // also checks that msg.sender owns this token
        uint256 taxAmount = (tokens * CLAIM_TOKEN_TAX_PERCENTAGE + 9999) /
            10000; // +99 to round the division up

        totalClaimed += tokens - taxAmount;
        totalTaxed += taxAmount;
        if (tokens != 0) stakes[tokenId].startTimestamp = block.timestamp;

        if (_unstake) {
            unstake(tokenId);
        }

        uint256 fee1 = (totalTaxed * 90) / 100;
        uint256 fee2 = (totalTaxed * 10) / 100;

        // ryuToken.mint(_msgSender(), totalClaimed);
        // ryuToken.mint(Addr1, fee1);
        // ryuToken.mint(Addr2, fee2);

        ryuToken.transfer(_msgSender(), totalClaimed);
        ryuToken.transfer(ADDR1, totalClaimed);
        ryuToken.transfer(ADDR2, totalClaimed);
    }

    function claimAll(bool _unstake) external {
        uint256 totalClaimed = 0;
        uint256 totalTaxed = 0;
        OwnedStakeInfo[] memory stakesOfOwner = getStakedNftsOfOwner(
            _msgSender()
        );
        for (uint256 i = 0; i < stakesOfOwner.length; i++) {
            uint256 tokenId = stakesOfOwner[i].tokenId;
            uint256 tokens = _getTokensAccruedFor(tokenId, true); // also checks that msg.sender owns this token
            uint256 taxAmount = (tokens * CLAIM_TOKEN_TAX_PERCENTAGE + 9999) /
                10000; // +99 to round the division up

            totalClaimed += tokens - taxAmount;
            totalTaxed += taxAmount;
            if (tokens != 0) stakes[tokenId].startTimestamp = block.timestamp;

            if (_unstake) {
                unstake(tokenId);
            }
        }

        ryuToken.mint(_msgSender(), totalClaimed);
        uint256 fee1 = (totalTaxed * 90) / 100;
        uint256 fee2 = totalTaxed - fee1;

        ryuToken.mint(ADDR1, fee1);
        ryuToken.mint(ADDR2, fee2);
    }

    function unstake(uint256 tokenId) internal {
        StakeDetails memory stake = stakes[tokenId];

        require(_msgSender() == stake.owner, "You don't own this token");
        delete stakes[tokenId];
        _removeStakeFromOwnerEnumeration(_msgSender(), tokenId);
        nft.safeTransferFrom(address(this), _msgSender(), tokenId);
    }

    /**
     * @dev Changes pause state.
     */
    function flipPauseStatus() external onlyOwner {
        isPaused = !isPaused;
    }

    function _addNftToStaking(uint256 _tokenId, address _owner) internal {
        stakes[_tokenId] = StakeDetails({
            owner: _owner,
            tokenId: _tokenId,
            isLegend: nft.isLegend(_tokenId),
            startTimestamp: block.timestamp,
            staked: true
        });
        _addStakeToOwnerEnumeration(_owner, _tokenId);
    }

    /* Enumeration, adopted from OpenZeppelin ERC721Enumerable */

    function stakeOfOwnerByIndex(address _owner, uint256 _index)
        public
        view
        returns (uint256)
    {
        require(
            _index < ownedStakesBalance[_owner],
            "owner index out of bounds"
        );
        return ownedStakes[_owner][_index];
    }

    function getUnstakedNftsOfOwner(address _owner)
        public
        view
        returns (OwnedStakeInfo[] memory)
    {
        uint256 supply = nft.totalSupply();
        uint256 outputSize = nft.balanceOf(_owner);
        OwnedStakeInfo[] memory outputs = new OwnedStakeInfo[](outputSize);
        uint256 cnt = 0;
        for (uint256 i = 0; i < supply; i++) {
            if (nft.ownerOf(i) == _owner) {
                outputs[cnt] = OwnedStakeInfo({
                    tokenId: i,
                    rewardPerday: getDayReward(i),
                    accrual: 0,
                    tokenURI: nft.tokenURI(i)
                });
                cnt++;
            }
        }
        return outputs;
    }

    function getStakedNftsOfOwner(address _owner)
        public
        view
        returns (
            // uint256 _offset,
            // uint256 _maxSize
            OwnedStakeInfo[] memory
        )
    {
        // if (_offset >= ownedStakesBalance[_owner]) {
        //     return new OwnedStakeInfo[](0);
        // }

        // uint256 outputSize = _maxSize;
        // if (_offset + _maxSize >= ownedStakesBalance[_owner]) {
        //     outputSize = ownedStakesBalance[_owner] - _offset;
        // }
        uint256 outputSize = ownedStakesBalance[_owner];
        OwnedStakeInfo[] memory outputs = new OwnedStakeInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            // uint256 tokenId = stakeOfOwnerByIndex(_owner, _offset + i);
            uint256 tokenId = stakeOfOwnerByIndex(_owner, i);

            outputs[i] = OwnedStakeInfo({
                tokenId: tokenId,
                rewardPerday: getDayReward(tokenId),
                accrual: _getTokensAccruedFor(tokenId, false),
                tokenURI: nft.tokenURI(tokenId)
            });
        }

        return outputs;
    }

    function getDayReward(uint256 tokenId) internal view returns (uint256) {
        if (nft.isLegend(tokenId)) return LEGEND_REWARD_PER_DAY;
        else return BASE_REWARD_PER_DAY;
    }

    function _addStakeToOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 length = ownedStakesBalance[_owner];
        ownedStakes[_owner][length] = _tokenId;
        ownedStakesIndex[_tokenId] = length;
        ownedStakesBalance[_owner]++;
    }

    function _removeStakeFromOwnerEnumeration(address _owner, uint256 _tokenId)
        private
    {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ownedStakesBalance[_owner] - 1;
        uint256 tokenIndex = ownedStakesIndex[_tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedStakes[_owner][lastTokenIndex];

            ownedStakes[_owner][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ownedStakesIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete ownedStakesIndex[_tokenId];
        delete ownedStakes[_owner][lastTokenIndex];
        ownedStakesBalance[_owner]--;
    }

    function cooldownOfOwnerByIndex(address _owner, uint256 _index)
        public
        view
        returns (uint256)
    {
        require(
            _index < ownedCooldownsBalance[_owner],
            "owner index out of bounds"
        );
        return ownedCooldowns[_owner][_index];
    }

    function batchedCooldownsOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (OwnedCooldownInfo[] memory) {
        if (_offset >= ownedCooldownsBalance[_owner]) {
            return new OwnedCooldownInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedCooldownsBalance[_owner]) {
            outputSize = ownedCooldownsBalance[_owner] - _offset;
        }
        OwnedCooldownInfo[] memory outputs = new OwnedCooldownInfo[](
            outputSize
        );

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = cooldownOfOwnerByIndex(_owner, _offset + i);

            outputs[i] = OwnedCooldownInfo({
                tokenId: tokenId,
                startTimestamp: unstakeCooldowns[tokenId].startTimestamp
            });
        }

        return outputs;
    }

    function _addCooldownToOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 length = ownedCooldownsBalance[_owner];
        ownedCooldowns[_owner][length] = _tokenId;
        ownedCooldownsIndex[_tokenId] = length;
        ownedCooldownsBalance[_owner]++;
    }

    function _removeCooldownFromOwnerEnumeration(
        address _owner,
        uint256 _tokenId
    ) private {
        uint256 lastTokenIndex = ownedCooldownsBalance[_owner] - 1;
        uint256 tokenIndex = ownedCooldownsIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedCooldowns[_owner][lastTokenIndex];
            ownedCooldowns[_owner][tokenIndex] = lastTokenId;
            ownedCooldownsIndex[lastTokenId] = tokenIndex;
        }

        delete ownedCooldownsIndex[_tokenId];
        delete ownedCooldowns[_owner][lastTokenIndex];
        ownedCooldownsBalance[_owner]--;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
