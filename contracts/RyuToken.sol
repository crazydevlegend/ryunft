// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RyuToken is ERC20("Ryu", "Ryu"), Ownable {
    address public stakingAddress;
    uint256 public maxSupply = 10000000 ether;

    constructor() {
        _mint(msg.sender, 3250000 ether);
    }

    function setStakingAddress(address _stakingAddress) external onlyOwner {
        require(
            address(stakingAddress) == address(0),
            "Staking address already set"
        );
        stakingAddress = _stakingAddress;
    }

    function mint(address _to, uint256 _amount) external {
        require(
            _msgSender() == stakingAddress,
            "Only the Staking contract can mint"
        );
        require(totalSupply() + _amount <= maxSupply, "Max supply reached.");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        _burn(_from, _amount);
    }
}
