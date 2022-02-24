// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "./Ryu.sol";

contract Ryu_V2 is Ryu {
    bool constant updated = false;
    // mapping that save legendary dragon
    mapping(uint256 => bool) public isLegends;

    // function that set legendary dragons, ownerOnly
    function setLegends(uint256[] memory _tokenIds) external onlyOwner {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            isLegends[i] = true;
        }
    }

    function isLegend(uint256 _tokenId) public view returns (bool) {
        if (isLegends[_tokenId]) return true;
        else return false;
    }

    function isUpdated() public pure returns (bool) {
        return updated;
    }
}
