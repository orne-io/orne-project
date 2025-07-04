// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ORNE Staking Vault
 * @dev Vault de staking avec rewards et tracking CO2
 */
contract ORNEStakingVault is Ownable, ReentrancyGuard {
    IERC20 public immutable orneToken;
    
    // Paramètres du staking
    uint256 public unstakingDelay = 21 days;
    
    // Tracking des stakes
    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 rewardDebt;
        uint256 co2BaselinePerOrne; // CO2 par ORNE au moment du stake
    }
    
    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public pendingUnstakes;
    mapping(address => uint256) public unstakeTimestamps;
    
    // Rewards
    uint256 public totalStaked;
    uint256 public accRewardsPerShare;
    uint256 public totalRewardsDeposited;
    
    // Tracking CO2
    uint256 public co2PerOrne; // en grammes de CO2 par ORNE depuis le lancement
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event UnstakeRequested(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDeposited(uint256 amount);
    event CO2Updated(uint256 addedTonnes, uint256 newCO2PerOrne);
    event UnstakingDelayUpdated(uint256 newDelay);
    
    constructor(address _orneToken) {
        orneToken = IERC20(_orneToken);
    }
    
    /**
     * @dev Stake des tokens ORNE
     * @param amount Montant à stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        
        // Claim pending rewards avant de modifier le stake
        _claimRewards(msg.sender);
        
        // Transfer tokens
        orneToken.transferFrom(msg.sender, address(this), amount);
        
        // Update stake info
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].timestamp = block.timestamp;
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * accRewardsPerShare) / 1e18;
        stakes[msg.sender].co2BaselinePerOrne = co2PerOrne;
        
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @dev Demande d'unstake avec délai
     * @param amount Montant à unstake
     */
    function requestUnstake(uint256 amount) external {
        require(stakes[msg.sender].amount >= amount, "Insufficient staked amount");
        require(amount > 0, "Amount must be > 0");
        
        // Claim pending rewards
        _claimRewards(msg.sender);
        
        // Update stake
        stakes[msg.sender].amount -= amount;
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * accRewardsPerShare) / 1e18;
        
        // Set unstake request
        pendingUnstakes[msg.sender] += amount;
        unstakeTimestamps[msg.sender] = block.timestamp;
        
        totalStaked -= amount;
        
        emit UnstakeRequested(msg.sender, amount);
    }
    
    /**
     * @dev Finalise l'unstake après le délai
     */
    function unstake() external nonReentrant {
        uint256 amount = pendingUnstakes[msg.sender];
        require(amount > 0, "No pending unstake");
        require(
            block.timestamp >= unstakeTimestamps[msg.sender] + unstakingDelay,
            "Unstaking delay not met"
        );
        
        pendingUnstakes[msg.sender] = 0;
        unstakeTimestamps[msg.sender] = 0;
        
        orneToken.transfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev Claim les rewards accumulés
     */
    function claimRewards() external {
        _claimRewards(msg.sender);
    }
    
    /**
     * @dev Logique interne de claim des rewards
     */
    function _claimRewards(address user) internal {
        uint256 userStaked = stakes[user].amount;
        if (userStaked == 0) return;
        
        uint256 pending = (userStaked * accRewardsPerShare) / 1e18 - stakes[user].rewardDebt;
        
        if (pending > 0) {
            orneToken.transfer(user, pending);
            stakes[user].rewardDebt = (userStaked * accRewardsPerShare) / 1e18;
            emit RewardsClaimed(user, pending);
        }
    }
    
    /**
     * @dev Dépose des rewards pour tous les stakers
     * @param amount Montant de rewards à distribuer
     */
    function depositRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(totalStaked > 0, "No staked tokens");
        
        orneToken.transferFrom(msg.sender, address(this), amount);
        
        accRewardsPerShare += (amount * 1e18) / totalStaked;
        totalRewardsDeposited += amount;
        
        emit RewardsDeposited(amount);
    }
    
    /**
     * @dev Met à jour les métriques CO2 (admin only)
     * @param addedTonnes Tonnes de CO2 capturées à ajouter
     */
    function updateCO2(uint256 addedTonnes) external onlyOwner {
        require(addedTonnes > 0, "Added tonnes must be > 0");
        
        // Convertir tonnes en grammes et calculer par ORNE
        uint256 addedGrams = addedTonnes * 1e6; // 1 tonne = 1,000,000 grammes
        
        if (totalStaked > 0) {
            co2PerOrne += (addedGrams * 1e18) / totalStaked;
        }
        
        emit CO2Updated(addedTonnes, co2PerOrne);
    }
    
    /**
     * @dev Calcule le CO2 offset pour un utilisateur
     * @param user Adresse de l'utilisateur
     * @return CO2 offset en grammes
     */
    function co2OffsetOf(address user) external view returns (uint256) {
        uint256 userStaked = stakes[user].amount;
        if (userStaked == 0) return 0;
        
        uint256 co2Growth = co2PerOrne - stakes[user].co2BaselinePerOrne;
        return (userStaked * co2Growth) / 1e18;
    }
    
    /**
     * @dev Calcule les rewards pending pour un utilisateur
     * @param user Adresse de l'utilisateur
     * @return Rewards pending
     */
    function pendingRewards(address user) external view returns (uint256) {
        uint256 userStaked = stakes[user].amount;
        if (userStaked == 0) return 0;
        
        return (userStaked * accRewardsPerShare) / 1e18 - stakes[user].rewardDebt;
    }
    
    /**
     * @dev Vérifie si un unstake est disponible
     * @param user Adresse de l'utilisateur
     * @return true si l'unstake est disponible
     */
    function canUnstake(address user) external view returns (bool) {
        return pendingUnstakes[user] > 0 && 
               block.timestamp >= unstakeTimestamps[user] + unstakingDelay;
    }
    
    /**
     * @dev Temps restant avant de pouvoir unstake
     * @param user Adresse de l'utilisateur
     * @return Secondes restantes
     */
    function timeUntilUnstake(address user) external view returns (uint256) {
        if (pendingUnstakes[user] == 0) return 0;
        
        uint256 unlockTime = unstakeTimestamps[user] + unstakingDelay;
        if (block.timestamp >= unlockTime) return 0;
        
        return unlockTime - block.timestamp;
    }
    
    /**
     * @dev Met à jour le délai d'unstaking (admin only)
     * @param newDelay Nouveau délai en secondes
     */
    function setUnstakingDelay(uint256 newDelay) external onlyOwner {
        require(newDelay <= 365 days, "Delay too long");
        unstakingDelay = newDelay;
        emit UnstakingDelayUpdated(newDelay);
    }
    
    /**
     * @dev Fonction d'urgence pour récupérer des tokens (admin only)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
