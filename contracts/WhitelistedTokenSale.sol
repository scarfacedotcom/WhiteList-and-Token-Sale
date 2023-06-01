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
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    //JGK 6/1/23 - removing the below as we will only accept DAI.
    //EnumerableSet.AddressSet internal customerTokens;

    IERC20 public tokenToSell;
    ITokenSaleRegistry public tokenSaleWhitelistRegistry;
    bool public whitelistEnabled;

    address public wallet;

    //TODO: remove the below variable and references to it after testing.
    uint256 public lastResultTokenAmount;
    event ContractReceivedTokens(address indexed from, uint256 amount);
    event ContractFallbackReceivedTokens(address indexed from, uint256 amount);

    //TODO: allow contract owner/admin to be able to set this or use the addOrUpdateCustomerToken function.
    uint256 public tokensPerEth = 20; //1 Eth is $1 USD. So, 20 tokens can be purchased for 1 ETH (.05 for each of our tokens)

    struct TokenInfo {
        uint256 rateMul;
        uint256 rateDiv;
        uint256 totalReceived;
        uint256 totalSold;
    }

    mapping(address => TokenInfo) public customerTokenInfo;

    constructor() {
    }

    function initialize(address _owner, address _tokenToSell, address _tokenSaleRegistry, bool _whitelistEnabled) public initializer {
        Ownable.initialize(_owner);
        tokenToSell = IERC20(_tokenToSell);
        tokenSaleWhitelistRegistry = ITokenSaleRegistry(_tokenSaleRegistry);
        whitelistEnabled = _whitelistEnabled;
    }

    function setTokenSaleWhitelistRegistry(ITokenSaleRegistry _tokenSaleWhitelistRegistry, bool _whitelistEnabled) external onlyAdmin {
        tokenSaleWhitelistRegistry = _tokenSaleWhitelistRegistry;
        whitelistEnabled = _whitelistEnabled;
        emit SetTokenSaleRegistry(address(_tokenSaleWhitelistRegistry), msg.sender, _whitelistEnabled);
    }

    function setWallet(address _wallet) external onlyAdmin {
        wallet = _wallet;
        emit SetWallet(_wallet, msg.sender);
    }

    function setWhitelistEnabled(bool _isEnabled) external onlyAdmin {
        whitelistEnabled = _isEnabled;
    }

/* JGK 6/1/23 - removing the below functions as we will only accept DAI.
    function addOrUpdateCustomerToken(address _token, uint256 _rateMul, uint256 _rateDiv) external onlyAdmin {
        require(_rateMul > 0 && _rateDiv > 0, "WhitelistedTokenSale: incorrect rate");
        customerTokens.add(_token);
        customerTokenInfo[_token].rateMul = _rateMul;
        customerTokenInfo[_token].rateDiv = _rateDiv;
        emit UpdateCustomerToken(_token, _rateMul, _rateDiv, msg.sender);
    }

    function removeCustomerToken(address _token) external onlyAdmin {
        customerTokens.remove(_token);
        emit RemoveCustomerToken(_token, msg.sender);
    }

    
    function getTokenAmount(address _customerToken, uint256 _weiAmount) public view returns (uint256) {
        TokenInfo storage _tokenInfo = customerTokenInfo[_customerToken];
        return _weiAmount.mul(_tokenInfo.rateMul).div(_tokenInfo.rateDiv);
    }

    function isTokenAvailable(address _customerToken) public view returns (bool) {
        return customerTokens.contains(_customerToken);
    }

    function getCustomerTokenList() external view returns (address[] memory) {
      
        //JGK 5/25/23 - adjusted below code because .enumerate was throwing a compiler error.
        //return customerTokens.enumerate();

        uint256 length = customerTokens.length();
        address[] memory tokens = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
          tokens[i] = customerTokens.at(i);
        }
        
        return tokens;
    }

    function getCustomerTokenCount() external view returns (uint256) {
        return customerTokens.length();
    }
    */

/*
    function buyTokens(IERC20 _customerToken, address _customerAddress, uint256 _weiAmount) external whenNotPaused {
        require(wallet != address(0), "WhitelistedTokenSale: wallet is null");
        require(_weiAmount > 0, "WhitelistedTokenSale: weiAmount can't be null");
        require(isTokenAvailable(address(_customerToken)), "WhitelistedTokenSale: _customerToken is not available");

        if (whitelistEnabled) {
          tokenSaleRegistry.validateWhitelistedCustomer(_customerAddress);
        }

        uint256 _resultTokenAmount = getTokenAmount(address(_customerToken), _weiAmount);
        require(_resultTokenAmount > 0, "WhitelistedTokenSale: _resultTokenAmount can't be null");

        lastResultTokenAmount = _resultTokenAmount;

        TokenInfo storage _tokenInfo = customerTokenInfo[address(_customerToken)];
        _tokenInfo.totalReceived = _tokenInfo.totalReceived.add(_weiAmount);
        _tokenInfo.totalSold = _tokenInfo.totalSold.add(_resultTokenAmount);

        emit BuyTokens(msg.sender, _customerAddress, address(_customerToken), _weiAmount, _resultTokenAmount);

        //send the customer's DAI to our wallet. msg.sender is the person calling this function.
        //JGK 5/29/23 - replaced safeTransferFrom with transfer which should be fine because
        //the person executing this method can do the approval. Otherwise, a pre-approval seems
        //like it would need performed in order to use the safeTransferFrom method.
        _customerToken.safeTransferFrom(msg.sender, wallet, _weiAmount);
        //_customerToken.transfer(wallet, _weiAmount);

        //send our token that they're buying to their address.
        tokenToSell.safeTransfer(_customerAddress, _resultTokenAmount);
    }


    function buyTokens2(IERC20 _customerToken, address _customerAddress, uint256 _weiAmount) external whenNotPaused {
        
        require(wallet != address(0), "WhitelistedTokenSale: wallet is null");
        require(_weiAmount > 0, "WhitelistedTokenSale: weiAmount can't be null");
        require(isTokenAvailable(address(_customerToken)), "WhitelistedTokenSale: _customerToken is not available");


        if (whitelistEnabled) {
          tokenSaleRegistry.validateWhitelistedCustomer(_customerAddress);
        }

        uint256 _resultTokenAmount = getTokenAmount(address(_customerToken), _weiAmount);
        require(_resultTokenAmount > 0, "WhitelistedTokenSale: _resultTokenAmount can't be null");

        lastResultTokenAmount = _resultTokenAmount;

        TokenInfo storage _tokenInfo = customerTokenInfo[address(_customerToken)];
        _tokenInfo.totalReceived = _tokenInfo.totalReceived.add(_weiAmount);
        _tokenInfo.totalSold = _tokenInfo.totalSold.add(_resultTokenAmount);

        emit BuyTokens(msg.sender, _customerAddress, address(_customerToken), _weiAmount, _resultTokenAmount);

        //send the customer's DAI to our wallet. msg.sender is the person calling this function.
        //JGK 5/29/23 - replaced safeTransferFrom with transfer which should be fine because
        //the person executing this method can do the approval. Otherwise, a pre-approval seems
        //like it would need performed in order to use the safeTransferFrom method.
        //_customerToken.safeTransferFrom(msg.sender, wallet, _weiAmount);
        //_customerToken.transfer(wallet, _weiAmount);

        //send our token that they're buying to their address.
        //tokenToSell.safeTransfer(_customerAddress, _resultTokenAmount);
        
        IERC20(tokenToSell).transfer(_customerAddress, _resultTokenAmount);
    }



    //JGK 5/30/23 - added below functions in here from the MyWhitelist.sol file
    function buyTokens3(IERC20 _customerToken, uint256 _weiAmount) external payable {

        
        //uint256 tokensToBuy;
        //tokensToBuy = msg.value;
        //_customerToken.transfer(wallet, amount);

        //_transfer(address(this), msg.sender, tokensToBuy);

        //transfer the tokens user is using to pay for our token.
        _customerToken.transfer(wallet, _weiAmount);


        //IERC20(tokenToSell).transferFrom(address(this), msg.sender, _weiAmount);

        //IERC20(tokenToSell).transfer(msg.sender, amount);
    }


    function buyTokens4(address tokenContractAddress, uint256 amount) external payable {
        // Calculate the price based on the token price and amount
        uint256 tokenPrice = 50000000000000000; //.05 - 5 cents per token
        uint256 price = amount * tokenPrice;

        // Make sure the user has waited for the cooldown period
        //require(block.timestamp >= lastPurchaseTimestamp[msg.sender] + cooldownPeriod, "Cooldown period not over");

        // Check if the contract has the necessary allowance to spend tokens on behalf of the user
        IERC20 tokenContract = IERC20(tokenContractAddress);
        require(tokenContract.allowance(msg.sender, msg.sender) >= amount, "Insufficient allowance");

        // Check if the user has enough token balance
        require(tokenContract.balanceOf(msg.sender) >= amount, "Insufficient token balance");

        // Transfer tokens from the user's account to the wallet
        tokenContract.transferFrom(msg.sender, wallet, amount);

        // Update the last purchase timestamp for the user
        //lastPurchaseTimestamp[msg.sender] = block.timestamp;

        // Refund any excess ether sent by the user
        if (msg.value > price) {
            uint256 refundAmount = msg.value - price;
            payable(msg.sender).transfer(refundAmount);
        }
    }



    function approveBuyTokens(IERC20 _customerToken, uint256 _weiAmount) external
    {
        _customerToken.approve(address(this), _weiAmount);
    }

    //JGK 5/30/23 - added below functions in here from the MyWhitelist.sol file
    function buyTokens5(IERC20 _customerToken, uint256 _weiAmount) external payable {

        
        //uint256 tokensToBuy;
        //tokensToBuy = msg.value;
        //_customerToken.transfer(wallet, amount);

        //_transfer(address(this), msg.sender, tokensToBuy);

        //transfer the tokens user is using to pay for our token.
        //_customerToken.transfer(wallet, _weiAmount);


        IERC20(tokenToSell).transferFrom(msg.sender, wallet, _weiAmount);

        //IERC20(tokenToSell).transfer(msg.sender, amount);
    }
    */

    /**
    * @notice Allow users to buy token for ETH
    */
    function buyTokens6Working() public payable returns (uint256 tokenAmount) {
        require(msg.value > 0, "Send ETH to buy some tokens");

        uint256 amountToBuy = msg.value * tokensPerEth;

        // check if the Vendor Contract has enough amount of tokens for the transaction
        uint256 vendorBalance = tokenToSell.balanceOf(address(this));
        require(vendorBalance >= amountToBuy, "Vendor contract has not enough tokens in its balance");

        // Transfer token to the msg.sender
        (bool sent) = tokenToSell.transfer(msg.sender, amountToBuy);
        require(sent, "Failed to transfer token to user");

        // emit the event
        //emit BuyTokens(msg.sender, msg.value, amountToBuy);

        //event BuyTokens(address indexed spender, address indexed customer, address indexed token, uint256 tokenAmount, uint256 resultAmount);
        //emit BuyTokens(msg.sender, msg.sender, address(_customerToken), msg.value, amountToBuy);

        return amountToBuy;
    }

    /**
    * @notice Allow users to buy token for ETH
      @dev When a function in a Solidity contract is marked as payable, it means the function can receive Ether directly. 
    */
    function buyTokens7() public payable returns (uint256 tokenAmount) {
        require(msg.value > 0, "Send ETH to buy some tokens");

        // Ensure that the received token is Ether (not a contract address for another type of token)
        address ethAddress = address(0); // Note: Ether does not have a contract address
        require(msg.sender == ethAddress, "Only Ether is allowed!");

        uint256 amountToBuy = msg.value * tokensPerEth;

        // check if the Vendor Contract has enough amount of tokens for the transaction
        uint256 vendorBalance = tokenToSell.balanceOf(address(this));
        require(vendorBalance >= amountToBuy, "Vendor contract has not enough tokens in its balance");

        // Transfer token to the msg.sender
        (bool sent) = tokenToSell.transfer(msg.sender, amountToBuy);
        require(sent, "Failed to transfer token to user");

        // emit the event
        //emit BuyTokens(msg.sender, msg.value, amountToBuy);

        //event BuyTokens(address indexed spender, address indexed customer, address indexed token, uint256 tokenAmount, uint256 resultAmount);
        //emit BuyTokens(msg.sender, msg.sender, address(_customerToken), msg.value, amountToBuy);

        return amountToBuy;
    }

    function getTokenBalanceAnyWallet(address someOwner) public view returns(uint256){
        return IERC20(tokenToSell).balanceOf(someOwner); 
    }

    /// @dev View-only function to return this contract's balance in WEI
    ///    NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE MAIN TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS 
    ///    OF THE MYTOKEN ITSELF WHICH WAS PASSED INTO THE CONSTRUCTOR DURING THE DEPLOYMENT OF THIS MyTimeLocak SMART CONTRACT.
    ///    Anyone can send any type of tokens to the address of a smart contract such as this. They essentially just recorded in a ledger somewhere
    ///    of the token that is being transferred. So, this function goes out to the myToken's smart contract address and gets the balance owned
    ///    of our specific token, and owned by THIS (MyTimeLock's) address.
    /// @return Full contract balance in WEI (with 18 0's after it). 
    function getContractBalance() public view returns(uint256){
        return IERC20(tokenToSell).balanceOf(address(this)); 
    }

    /// @dev View-only function to return this contract's balance in whole tokens
    ///    NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE MAIN TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS 
    ///    OF THE MYTOKEN ITSELF WHICH WAS PASSED INTO THE CONSTRUCTOR DURING THE DEPLOYMENT OF THIS MyTimeLocak SMART CONTRACT.
    ///    Anyone can send any type of tokens to the address of a smart contract such as this. They essentially just recorded in a ledger somewhere
    ///    of the token that is being transferred. So, this function goes out to the myToken's smart contract address and gets the balance owned
    ///    of our specific token, and owned by THIS (MyTimeLock's) address.
    /// @return Full contract balance in ETH (whole tokens WITHOUT 18 0's after it). 
    function getContractBalanceWholeTokens() public view returns(uint256){
        uint256 fullBalance = getContractBalance(); 

        if(fullBalance > 0)
        {
            /*
            uint256 erc20BalanceWholeValue = getContractBalance() / (10**18);
            return erc20BalanceWholeValue;
            */

            return convertWeiToEther(fullBalance);
        }
        else 
        {
            return 0;
        }
    }

    function convertWeiToEther(uint256 amountInWei) public pure returns (uint256) {
        uint256 amountInEther = amountInWei.div(1 ether);
        return amountInEther;
    }

    /**
    * @notice Allow the owner of the contract to withdraw ETH
    */
    function withdraw() public onlyOwner {
        uint256 ownerBalance = address(this).balance;
        require(ownerBalance > 0, "Owner has not balance to withdraw");

        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send user balance back to the owner");
    }


    /// @dev The receive function must be in here in order for the contract to be able to receive tokens and hold onto them. 
    receive() external payable{
        
        //Just a note that I removed the onlyOwner modifier in the above receive() declaration because when we send our tokens to this
        //contract, they will most likely be coming from a master account rather than the owner of this contract which will be a different account.
        //Anyone can transfer tokens to the address of a smart contract.  However, in the releaseTokens function and in any calls to get
        //balances, it will always reach out using the Token Contract Address passed into the constructor of this smart contract. Therefore,
        //the balances and payouts will only ever operate on the MyToken itself, regardless of if this MyTimeLock smart contract has received
        //funds from other tokens.  
        
        //log
        emit ContractReceivedTokens(msg.sender, msg.value);
    }    
    
    /// @dev As per best practices, it is good to have a fallback receive function to allow the contract to receive tokens if an error occurs.
    fallback() external payable {
        
        emit ContractFallbackReceivedTokens(msg.sender, msg.value);
    }

/*
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }



*/

}
