// SPDX-License-Identifier: Galt Project Society Construction and Terraforming Company
/*
 * Copyright ©️ 2018-2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2018-2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity >=0.5.0 <0.9.0;
//pragma solidity ^0.5.13;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IWhitelistedTokenSale.sol";
import "./interfaces/ITokenSaleRegistry.sol";
import "./traits/Administrated.sol";
import "./traits/Pausable.sol";

contract WhitelistedTokenSale is Administrated, IWhitelistedTokenSale, Pausable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public tokenToSell;
    ITokenSaleRegistry public tokenSaleWhitelistRegistry;
    bool public whitelistEnabled;

    address public wallet;

    event ContractReceivedTokens(address indexed from, uint256 amount);
    event ContractFallbackReceivedTokens(address indexed from, uint256 amount);
    event BuyTokens(address indexed customer, uint256 ethAmount, uint256 tokenAmount);

    //allow contract owner/admin to be able to set this or use the addOrUpdateCustomerToken function.
    uint256 public tokensPerEthMultiplier = 20; //1 Eth/DAI is $1 USD. So, 20 tokens can be purchased for 1 ETH (.05 for each of our tokens). 1:20. 1 ETH will be equal to 20 of our token.
    uint256 public tokensPerEthDivisor = 1; //could pass in 20 as the divisor so that 20:1 takes affect and our token is more valuable than ETH/DAI. 1 ETH will be equal to .05 our token.

    uint256 public coolDownPeriodInSeconds = 3600; //default to 1 hours (60 seconds in 1 minute * 60 minutes in 1 hour = 3600 seconds);
    mapping(address => uint256) public lastPurchaseTimestamp;

    constructor() {
    }
    

    ///@dev The contract owner must call this function immediately after contract deployment to set initial parameters.
    ///@param _owner - the account owner's address which is typically the address of the account used to deploy this contract.
    ///@param _tokenToSell - the contract address of our token that we're selling.
    ///@param _tokenSaleRegistry - the contract address of the TokenSaleRegistry contract where whitelisted addresses can be placed.
    ///@param _whitelistEnabled - whether we want whitelisting lookups during the Buy operations enabled/disabled. This can be changed 
    ///     later with calls to either the setTokenSaleWhitelistRegistry function or the setWhitelistEnabled functions.
    ///@param _tokensPerEthMultiplier is the multiplier. 20 would mean 1:20. 1 ETH/DAI would allow them to purchase 20 tokens.
    ///@param _tokensPerEthDivisor is the divisor. Typically we would send a 1 in here unless the cost of our token ends up being priced higher than the price of an ETH/DAI.
    ///     If we pass in 20 as the divisor then 1 ETH will send buyer .05 of our tokens or 20:1 ration.
    function initialize(address _owner, address _tokenToSell, address _tokenSaleRegistry, bool _whitelistEnabled, uint256 _tokensPerEthMultiplier, uint256 _tokensPerEthDivisor) public initializer {
        Ownable.initialize(_owner);
        tokenToSell = IERC20(_tokenToSell);
        tokenSaleWhitelistRegistry = ITokenSaleRegistry(_tokenSaleRegistry);
        whitelistEnabled = _whitelistEnabled;
        tokensPerEthMultiplier = _tokensPerEthMultiplier;
        tokensPerEthDivisor = _tokensPerEthDivisor;
    }

    /// @dev The receive function must be in here in order for the contract to be able to receive tokens and hold onto them. 
    receive() external payable{
              
        //log
        emit ContractReceivedTokens(msg.sender, msg.value);
    }    
    
    /// @dev As per best practices, it is good to have a fallback receive function to allow the contract to receive tokens if an error occurs.
    fallback() external payable {
        
        emit ContractFallbackReceivedTokens(msg.sender, msg.value);
    }

    ///@dev allows admin to specify the lookup to an outside TokenSaleRegistry.sol deployed contract where whitelisted addresses will be held.
    ///@param _tokenSaleWhitelistRegistry - the contract for the TokenSaleRegistry
    ///@param _whitelistEnabled - whether we want whitelisting validation to take place during the Buy operations.
    function setTokenSaleWhitelistRegistry(ITokenSaleRegistry _tokenSaleWhitelistRegistry, bool _whitelistEnabled) external onlyAdmin {
        tokenSaleWhitelistRegistry = _tokenSaleWhitelistRegistry;
        whitelistEnabled = _whitelistEnabled;
        emit SetTokenSaleRegistry(address(_tokenSaleWhitelistRegistry), msg.sender, _whitelistEnabled);
    }

    ///@dev allows an admin to turn whitelist validation on/off
    ///@param _whitelistEnabled whether or not admin wants to turn whitelist lookup on/off
    function setWhitelistEnabled(bool _whitelistEnabled) external onlyAdmin {
        whitelistEnabled = _whitelistEnabled;
    }

    ///@dev allows admin to specify a wallet where all ETH/DAI used to purchase our token will be sent.
    ///@param _wallet is the wallet address where calls to buyToken may be sent vs being stored in this contract until manual withdraw takes place by admin.
    function setWallet(address _wallet) external onlyAdmin {
        wallet = _wallet;
        emit SetWallet(_wallet, msg.sender);
    }

    ///@dev allows admin to specify a multiplier and/or divisor for calculating price of our custom token in correspondence to amount of ETH/DAI passed in 
    ///     to the Buy operation.
    ///@param _tokensPerEthMultiplier is the multiplier. 20 would mean 1:20. 1 ETH/DAI would allow them to purchase 20 tokens.
    ///@param _tokensPerEthDivisor is the divisor. Typically we would send a 1 in here unless the cost of our token ends up being priced higher than the price of an ETH/DAI.
    function setTokenMath(uint256 _tokensPerEthMultiplier, uint256 _tokensPerEthDivisor) external onlyAdmin {
        require(_tokensPerEthMultiplier > 0 && _tokensPerEthDivisor > 0, "WhitelistedTokenSale: rates must be > 0");
        
        tokensPerEthMultiplier = _tokensPerEthMultiplier;
        tokensPerEthDivisor = _tokensPerEthDivisor;
    }

    ///@dev allows admin to specify how long customer must wait (in minutes) before executing a Buy operation again. Internally this is converted to seconds.
    ///@param _coolDownPeriodInMinutes time in minutes customer must wait before buying again.
    function setCoolDownPeriodInMinutes(uint256 _coolDownPeriodInMinutes) external onlyAdmin {

        coolDownPeriodInSeconds = _coolDownPeriodInMinutes * 60;
    }


    /// @notice Allow buyers of our custom token in exchange for ETH/DAI.
    /// @dev Allow users to buy tokens in exchange for ETH/DAI that is passed to this function. Function looks to see if whitelisting is enabled, and if so,
    //      it validates against an external whitelisting contract to ensure the buyer exists. Otherwise, it uses the multiplier and divisor the owner or admin has set
    ///     to calculate amount of our token to give back in correspondence.
    ///     The ETH/DAI passed to this function is stored within this wallet.
    /// @return amountToBuy count of our token that was bought.
    function buyTokensHoldInContract() external payable whenNotPaused returns (uint256) {
        
        // Ensure that the received token is Ether/DAI (not a contract address)
        //address ethAddress = address(0);
        //require(msg.sender == ethAddress, "Only Ether is allowed!");

        //require(wallet != address(0), "WhitelistedTokenSale: wallet is null");

        //ensure a 0 address wallet isn't being passed in.
        bool isValid = isValidWalletAddress(msg.sender);
        require(isValid, "Invalid wallet calling in.");

        //msg.value will be in wei units
        require(msg.value > 0, "Send ETH to buy some tokens");

        if (whitelistEnabled) {
          tokenSaleWhitelistRegistry.validateWhitelistedCustomer(msg.sender);
        }

         // Make sure the user has waited for the cooldown period
        require(block.timestamp >= lastPurchaseTimestamp[msg.sender] + coolDownPeriodInSeconds, "Cooldown period not over");

        uint256 amountToBuy = calculateTokenAmountInWei(msg.value);
        require(amountToBuy > 0, "WhitelistedTokenSale: amountToBuy must be > 0");

        // check if our balance of tokenToSell >= the amount being purchased right now. 
        uint256 ourBalance = tokenToSell.balanceOf(address(this));
        require(ourBalance >= amountToBuy, "Our token balance too low");

        // Update the last purchase timestamp for the user for the cooldown period
        lastPurchaseTimestamp[msg.sender] = block.timestamp;

        // Transfer token to the msg.sender
        (bool sent) = tokenToSell.transfer(msg.sender, amountToBuy);
        require(sent, "Failed to transfer tokens to customer");

        // emit the event
        emit BuyTokens(msg.sender, msg.value, amountToBuy);

        return amountToBuy;
    }

    /// @notice Allow buyers of our custom token in exchange for ETH/DAI.
    /// @dev Allow users to buy tokens in exchange for ETH/DAI that is passed to this function. Function looks to see if whitelisting is enabled, and if so,
    //      it validates against an external whitelisting contract to ensure the buyer exists. Otherwise, it uses the multiplier and divisor the owner or admin has set
    ///     to calculate amount of our token to give back in correspondence.
    ///     The ETH/DAI passed to this function is sent to an external wallet.
    /// @return amountToBuy count of our token that was bought.
    function buyTokensSendToWallet() external payable whenNotPaused returns (uint256) {

        // Ensure that the received token is Ether/DAI (not a contract address)
        //address ethAddress = address(0);
        //require(msg.sender == ethAddress, "Only Ether is allowed!");

        //require(wallet != address(0), "WhitelistedTokenSale: wallet is null");

        //ensure a 0 address wallet isn't being passed in.
        bool isValid = isValidWalletAddress(msg.sender);
        require(isValid, "Invalid wallet calling in.");

        //msg.value will be in wei units
        require(msg.value > 0, "Send ETH to buy some tokens");

        if (whitelistEnabled) {
          tokenSaleWhitelistRegistry.validateWhitelistedCustomer(msg.sender);
        }

        // Make sure the user has waited for the cooldown period
        require(block.timestamp >= lastPurchaseTimestamp[msg.sender] + coolDownPeriodInSeconds, "Cooldown period not over");

        uint256 amountToBuy = calculateTokenAmountInWei(msg.value);
        require(amountToBuy > 0, "WhitelistedTokenSale: amountToBuy must be > 0");

        // check if our balance of tokenToSell >= the amount being purchased right now. 
        uint256 ourBalance = tokenToSell.balanceOf(address(this));
        require(ourBalance >= amountToBuy, "Our token balance too low");

        // Update the last purchase timestamp for the user for the cooldown period
        lastPurchaseTimestamp[msg.sender] = block.timestamp;

        //send the customer's DAI to our specified wallet. 
        payable(wallet).transfer(msg.value);

        //send our token that they're buying to their address.
        (bool sent) = tokenToSell.transfer(msg.sender, amountToBuy);
        require(sent, "Failed to transfer tokens to customer");

        // emit the event
        emit BuyTokens(msg.sender, msg.value, amountToBuy);

        return amountToBuy;
    }


    /// @dev Takes in WEI amount that the Buyer has specified that they want to spend. It then uses the multiplier and divisor the owner or admin has set
    ///     to calculate amount of our token to give back in correspondence.
    /// @param _weiAmount is the amount in WEI with 18 0's that the buyer is spending of their ETH/DAI.
    /// @return amount of our token in WEI format.
    function calculateTokenAmountInWei(uint256 _weiAmount) public view returns (uint256) {
        return _weiAmount.mul(tokensPerEthMultiplier).div(tokensPerEthDivisor);
    }

    /// @dev Takes in WEI amount that the Buyer has specified that they want to spend. It then uses the multiplier and divisor the owner or admin has set
    ///     to calculate amount of our token to give back in correspondence.
    /// @param _weiAmount is the amount in WEI with 18 0's that the buyer is spending of their ETH/DAI.
    /// @return amount of our token in ETH/DAI full token format.
    function calculateTokenAmountInWeiWholeTokens(uint256 _weiAmount) public view returns (uint256) {
        uint256 tokensInWei = _weiAmount.mul(tokensPerEthMultiplier).div(tokensPerEthDivisor);

        return convertWeiToWholeTokens(tokensInWei);
    }

    /// @dev Gets amount in WEI of our token that any wallet currently owns.
    /// @param someOwner is any wallet address that owns some of our token.
    /// @return the amount in WEI of their balance.
    function getTokenBalanceAnyWallet(address someOwner) public view onlyAdmin returns(uint256){
        return IERC20(tokenToSell).balanceOf(someOwner); 
    }

    /// @dev View-only function to return this contract's token balance in WEI
    ///    NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE MAIN TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS 
    ///    OF THE tokenToSell ITSELF.
    /// @return Full contract balance in WEI format (with 18 0's after it). 
    function getContractTokenBalance() public view onlyAdmin returns(uint256){
        return IERC20(tokenToSell).balanceOf(address(this)); 
    }

    /// @dev View-only function to return this contract's token balance in whole tokens
    ///    NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE MAIN TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS 
    ///    OF THE tokenToSell ITSELF.
    /// @return Full contract balance in ETH (whole tokens WITHOUT 18 0's after it). 
    function getContractTokenBalanceWholeTokens() public view onlyAdmin returns(uint256){
        uint256 fullBalance = getContractTokenBalance(); 

        if(fullBalance > 0)
        {
            return convertWeiToWholeTokens(fullBalance);
        }
        else 
        {
            return 0;
        }
    }

    /// @dev View-only function to return this contract's Ether balance in WEI. As Buys are made, this contract receives Ether and sends out our custom token
    ///    based on the math conversion rate. 
    /// @return This contract's default Ether balance in WEI (with 18 0's after it). 
    function getContractEtherBalance() public view onlyAdmin returns(uint256){
        return address(this).balance;
    }

    /// @dev View-only function to return this contract's Ether balance in WEI. As Buys are made, this contract receives Ether and sends out our custom token
    ///    based on the math conversion rate. 
    /// @return This contract's default Ether balance in ETH format   
    function getContractEtherBalanceWholeTokens() public view onlyAdmin returns(uint256){
        uint256 fullBalance = getContractEtherBalance(); 

        if(fullBalance > 0)
        {
            return convertWeiToWholeTokens(fullBalance);
        }
        else 
        {
            return 0;
        }
    }

    /// @notice Allow the owner of the contract to withdraw our custom token.
    /// @dev Whichever admin calls this function will receive all custom tokens being held in this contract.
    function withdrawAllTokens() public onlyAdmin {
        uint256 thisBalance = tokenToSell.balanceOf(address(this));
        require(thisBalance > 0, "No contract balance of our token to withdraw");

        (bool sent) = tokenToSell.transfer(msg.sender, thisBalance);
        require(sent, "Failed to send contract tokens to admin");
    }

    /// @notice Allow the owner of the contract to withdraw our custom token.
    /// @param amount Amount of the custom token requesting to be sent to admin.
    /// @dev Whichever admin calls this function will receive the custom tokens being held in this contract.
    function withdrawTokens(uint amount) public onlyAdmin {
        uint256 thisBalance = tokenToSell.balanceOf(address(this)); 
        require(thisBalance > 0, "No contract balance of our token to withdraw");

        require(thisBalance >= amount, "Contract does not hold amount requested");

        (bool sent) = tokenToSell.transfer(msg.sender, amount);
        require(sent, "Failed to send contract tokens to admin");
    }


    /// @notice Allow the owner of the contract to withdraw ETH/DAI
    /// @dev Whichever admin calls this function will receive all the ETH/DAI being held in this contract.
    function withdrawAllEther() public onlyAdmin {
        uint256 thisBalance = address(this).balance;
        require(thisBalance > 0, "No contract balance to withdraw");

        //(bool sent,) = msg.sender.call{value: address(this).balance}("");
        //require(sent, "Failed to send contract balance back to the owner");

        payable(msg.sender).transfer(address(this).balance);

        
    }

    /// @notice Allow the owner of the contract to withdraw ETH/DAI
    /// @param amount Amount of the ETH/DAI requesting to be sent to admin.
    /// @dev Whichever admin calls this function will receive the ETH/DAI
    function withdrawEther(uint amount) public onlyAdmin {
        uint256 thisBalance = address(this).balance;
        require(thisBalance > 0, "No contract balance to withdraw");
        require(thisBalance >= amount, "Contract does not hold amount requested");

        //(bool sent,) = msg.sender.call{value: amount}("");
        //require(sent, "Failed to send contract balance back to the owner");

        payable(msg.sender).transfer(amount);
    }

    /// @dev Utilizes safemath function to convert wei to whole ETH/DAI amount.
    /// @param amountInWei The full amount with 18 0's in it.
    /// @return Full amount converted to whole ETH/DAI.
    //function convertWeiToWholeTokens(uint256 amountInWei) internal pure returns (uint256) {
    function convertWeiToWholeTokens(uint256 amountInWei) public pure returns (uint256) {
        uint256 amountInWholeTokens = amountInWei.div(1 ether);
        return amountInWholeTokens;
    }

    /// @dev The isValidWalletAddress checks to make sure the address has not be cleared/deleted by having a wallet voted out. When a wallet is voted out, the mapping
    ///    element in walletAddresses will still exist but will have been set to the below hex 0 value.
    /// @param walletToCheck The wallet address to check whether or not it is valid.
    /// @return true or false for whether or not the passed in wallet address is valid. 
    function isValidWalletAddress(address walletToCheck) private pure returns (bool){
        if(walletToCheck == 0x0000000000000000000000000000000000000000 ||
            walletToCheck == address(0) || 
             walletToCheck == address(0x0)) 
            return false;
         else 
            return true;
    }

}
