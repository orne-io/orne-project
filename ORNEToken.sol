// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ORNE Token
 * @dev Token ERC20 avec supply fixe et fonction burn
 */
contract ORNEToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18; // 100 millions
    
    constructor() ERC20("ORNE Token", "ORNE") {
        _mint(msg.sender, MAX_SUPPLY);
    }
    
    /**
     * @dev Burn des tokens
     * @param amount Montant à burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev Burn des tokens d'un autre compte (avec allowance)
     * @param account Compte dont on burn les tokens
     * @param amount Montant à burn
     */
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, msg.sender);
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, msg.sender, currentAllowance - amount);
        _burn(account, amount);
    }
}
