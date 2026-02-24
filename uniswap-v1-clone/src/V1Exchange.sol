// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract V1Exchange is ERC20 {
    address public tokenAddress;

    constructor(address token) ERC20("V1 ETH LP Token", "V1ELT") {
        require(token != address(0), "Invalid token address");
        tokenAddress = token;
    }

    function _getReserve() private view returns (uint256) {
        return ERC20(tokenAddress).balanceOf(address(this));
    }

    function getReserve() public view returns (uint256) {
        return _getReserve();
    }

    function addLiquidty(uint256 tokenAmount) public payable returns (uint256) {
        uint256 lpTokensToMint;
        uint256 ethReserveBalance = address(this).balance;
        uint256 tokenReserveBalance = _getReserve();

        ERC20 token = ERC20(tokenAddress);
        if (tokenReserveBalance == 0) {
            token.transferFrom(msg.sender, address(this), tokenAmount);
            lpTokensToMint = ethReserveBalance;
            _mint(msg.sender, lpTokensToMint);
            return lpTokensToMint;
        }
        uint ethReservePriorToFunctionCall = ethReserveBalance - msg.value;
        uint256 minTokenAmountRequired = (msg.value * tokenReserveBalance) /
            ethReservePriorToFunctionCall;
        require(
            tokenAmount >= minTokenAmountRequired,
            "Insufficient amount of tokens provided"
        );

        token.transferFrom(msg.sender, address(this), minTokenAmountRequired);

        lpTokensToMint =
            (totalSupply() * msg.value) /
            ethReservePriorToFunctionCall;

        _mint(msg.sender, lpTokensToMint);
        return lpTokensToMint;
    }

    function removeLiquidity(
        uint amountOfLpTokens
    ) public returns (uint256, uint256) {
        require(
            amountOfLpTokens > 0,
            "Amount of tokens to remove must be greater than 0"
        );

        uint256 ethReserveBalance = address(this).balance;
        uint256 lpTokenTotalSupply = totalSupply();

        uint256 ethToReturn = (ethReserveBalance * amountOfLpTokens) /
            lpTokenTotalSupply;
        uint256 tokenToReturn = (_getReserve() * amountOfLpTokens) /
            lpTokenTotalSupply;

        _burn(msg.sender, amountOfLpTokens);
        (bool success, ) = payable(msg.sender).call{value: ethToReturn}("");
        require(success, "ETH transfer failed");
        ERC20(tokenAddress).transfer(msg.sender, tokenToReturn);
        return (ethToReturn, tokenToReturn);
    }

    function getOutputAmountFromSwap(
        uint256 inputTokenAmount,
        uint256 inputTokenReserve,
        uint outputTokenReserve
    ) public pure returns (uint256) {
        require(
            inputTokenReserve > 0 && outputTokenReserve > 0,
            "Reserves must be greater than 0"
        );
        // Fee is 1 %
        uint256 inputTokenAmountWithFee = inputTokenAmount * 99;

        uint256 numerator = outputTokenReserve * inputTokenAmountWithFee;
        uint256 denominator = (inputTokenReserve * 100) +
            inputTokenAmountWithFee;

        return numerator / denominator;
    }

    function swapEthToToken(uint256 minTokensToReceive) public payable {
        uint256 tokensReserveBalance = _getReserve();
        uint256 tokensToReceive = getOutputAmountFromSwap(
            msg.value,
            address(this).balance - msg.value,
            tokensReserveBalance
        );

        require(
            tokensToReceive >= minTokensToReceive,
            "Tokens received are less than minimum tokens expected"
        );

        ERC20(tokenAddress).transfer(msg.sender, tokensToReceive);
    }

    function swapTokenToEth(
        uint256 tokensToSwap,
        uint256 mninEthToReceive
    ) public {
        uint256 tokenReserveBalance = _getReserve();
        uint256 ethReserveBalance = address(this).balance;
        uint256 ethToReceive = getOutputAmountFromSwap(
            tokensToSwap,
            tokenReserveBalance,
            ethReserveBalance
        );
        require(
            ethToReceive >= mninEthToReceive,
            "ETH received are less than minimum tokens expected"
        );
        (bool success, ) = payable(msg.sender).call{value: ethToReceive}("");
        require(success, "ETH Transaction failed");
    }
}
