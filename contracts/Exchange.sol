//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/IFactory.sol";
import "./interface/IExchange.sol";

contract Exchange is ERC20 { //LP토큰 발행, 소각하려면 ERC20 상속 받아야 함
    IERC20 token;
    IFactory factory;

    // Events
    event TokenPurchase(address indexed buyer, uint256 indexed eth_sold, uint256 indexed tokens_bought);
    event EthPurchase(address indexed buyer, uint256 indexed tokens_sold, uint256 indexed eth_bought);
    event AddLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);
    event RemoveLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);

    constructor (address _token) ERC20("Manaswap V2", "MNA-V2") { //이더리움과 페어를 맺을 토큰 주소
        require(address(factory) == address(0) && address(token) == address(0) && _token != address(0));
        token = IERC20(_token);
        factory = IFactory(msg.sender);
    }

    //유동성 공급 함수 수정!
    function addLiquidity(uint256 _maxTokens) public payable returns (uint256) {
        require(_maxTokens > 0 && msg.value > 0);
        
        uint256 totalLiquidity = totalSupply(); //전체 LP토큰 
        
        if(totalLiquidity > 0){ //(1)이미 유동성(풀)이 있는 상태에서 유동성(풀) 추가 
            uint256 etherReserve = address(this).balance - msg.value;  //기존 풀에 존재하는 이더 총량
            uint256 tokenReserve = token.balanceOf(address(this));     //기존 풀에 존재하는 마나 토큰 총량
            uint256 tokenAmount = msg.value * (tokenReserve/etherReserve); //내가 풀에 넣는 마나 토큰양 = 내가 넣는 이더양 * (토큰/이더 풀의 비율)

            require(_maxTokens >= tokenAmount); //내가 실제 풀에 넣는 마나 토큰양은 내가 입력한 마나 토큰양보단 적어야 함

            token.transferFrom(msg.sender, address(this), tokenAmount); //컨트랙트가 내가 공급한 마나 토큰을 가져감
            uint256 liquidityMinted = totalLiquidity * (msg.value/etherReserve); //내가 넣은 이더양이 풀 안의 이더양에서 차지하는 비율만큼 LP토큰 민팅
            _mint(msg.sender, liquidityMinted);

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(address(0), msg.sender, liquidityMinted);

            return liquidityMinted;

        }else{ //(2) 유동성이 없는 상태에서 처음으로 공급
            require(address(factory) != address(0) && address(token) != address(0) && msg.value > 1000000000);

            uint256 tokenAmount = _maxTokens; 
            uint256 initialLiquidity = address(this).balance;           //내가 풀에 넣는 마나 토큰양은 내가 입력한 유동성 총량 (1:1이므로) 
            _mint(msg.sender, initialLiquidity);                        //공급자에게 LP토큰 민팅
            
            require(token.transferFrom(msg.sender, address(this), tokenAmount)); //컨트랙트가 내가 공급한 그레이토큰을 가져감
        
            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(address(0), msg.sender, initialLiquidity);

            return initialLiquidity;
        }
    }

    //유동성 철회 함수
    function removeLiquidity(uint256 _lpToken) public payable returns (uint256, uint256){

        uint256 totalLiquidity = totalSupply();  //전체 LP토큰
        uint256 ethAmount = (_lpToken * address(this).balance) / totalLiquidity; //받아야할 이더양 = 반납한 lp토큰 * (이더가 전체 유동성에서 차지하는 비율)
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokenAmount = (_lpToken * tokenReserve) / totalLiquidity; //받아야할 마나토큰양 = 반납한 lp토큰 * (마나 토큰이 전체 유동성에서 차지하는 비율) 

        _burn(msg.sender, _lpToken); //내가 반납한 lp토큰 소각
        
        payable(msg.sender).transfer(ethAmount); //컨트랙트가 소각자에게 계산된 이더 전송
        token.transfer(msg.sender, tokenAmount); //컨트랙트가 소각자에게 계산된 마나 토큰 전송

        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
        emit Transfer(msg.sender, address(0), _lpToken);

        return (ethAmount, tokenAmount);

    }


    //이더리움 -> 토큰 swap or transfer 갈리기 전 공통 부분
    function ethToToken(uint256 _minTokens, address _recipient) private {
        uint256 outputAmount = getOutputAmount(
            msg.value,                       //사용자가 넣은 이더양
            address(this).balance-msg.value, //컨트랙트가 가진 이더양 (address(this).balance는 사용자가 입력한 이더양도 포함한 값이므로 inputAmount 빼줘야함)
            token.balanceOf(address(this))     //컨트랙트가 가진 마나 토큰양
        ); //밑에 작성한 받을 토큰양 정하는 함수

        require(outputAmount >= _minTokens, "Insufficient Output Amount"); //uint256 _minTokens 사용자가 프론트에서 입력한 값 (적어도 이 값보단 토큰 많이 받아야 함)
        require(token.transfer(_recipient, outputAmount));

        emit TokenPurchase( _recipient, msg.value, outputAmount);
        //IERC20(token).transfer(_recipient, outputAmount); //exchange 컨트랙트가 나에게 outputAmount 만큼 토큰을 transfer
    }

    //이더리움 -> 마나 토큰 스왑
    function ethToTokenSwap(uint256 _minTokens) public payable { 
        ethToToken(_minTokens, msg.sender); //ethToTokenSwap의 경우 recipient = msg.sender 마나 토큰 받는 사람의 주소
    }
    //이더리움 -> 문스톤 토큰 스왑으로 전달하기 위해 매개변수 그대로 전달
    function ethToTokenTransfer(uint256 _minTokens, address _recipient) public payable { 
        ethToToken(_minTokens, _recipient); //tokenToTokenSwap으로 보내기 위해 recipient 변수 그대로 전달
    }

    // 마나 토큰 -> 이더리움 스왑
    function tokenToEthSwap(uint256 _tokenSold, uint256 _minEth) public {
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 outputAmount = getOutputAmount(
            _tokenSold,
            tokenReserve,
            address(this).balance
        );

        require(outputAmount >= _minEth, "Insufficient output Amount");

        payable(msg.sender).transfer(_minEth); //컨트랙트가 스왑하는 사람에게 계산된 이더 전송
        require(token.transferFrom(msg.sender, address(this), _tokenSold));
    }

    // 마나 토큰 -> 문스톤 토큰 스왑
    function tokenToTokenSwap(uint256 _tokenSold, uint256 _minTokenBought, uint256 _minEthBought, address _tokenAddress) public payable{
        address toTokenExchangeAddress = factory.getExchange(_tokenAddress); //문스톤 토큰과 이더리움 스왑하는 Exchange 컨트랙트의 주소

        //마나 토큰->이더리움 스왑하면 받게 될 이더양 계산
        uint256 ethOutputAmount = getOutputAmount(_tokenSold, token.balanceOf(address(this)), address(this).balance);

        require(_minEthBought <= ethOutputAmount, "Insufficient eth output amount"); //프론트에서 입력하는 최소한의 이더양보다는 더 많이 받아야 함
        require(token.transferFrom(msg.sender, address(this), _tokenSold),"fail transfer");

        //컨트랙트가 스왑하는 사람의 마나 토큰 가져감
        //IERC20(token).transferFrom(msg.sender, address(this), _tokenSold);
        
        //문스톤 토큰과 이더리움을 스왑하는 컨트랙트의 인터페이스 호출
        IExchange(toTokenExchangeAddress).ethToTokenTransfer{value: ethOutputAmount}(_minTokenBought, msg.sender); //스왑 요청자에게 계산된 이더양만큼 패스트토큰과 스왑
        
    }



    //CSMM(수량 1:1 교환) 일 때의 가격 조회 함수
    function getPrice(uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        uint256 numerator = inputReserve;
        uint256 denominator = outputReserve;
        return numerator / denominator;
    }

    //받을 토큰양 정하는 함수 (수수료 부과 X)
    function getOutputAmountNoFee(
		uint256 inputAmount,  //사용자가 넣은 이더양
        uint256 inputReserve, //기존에 컨트랙트가 가진 이더양
        uint256 outputReserve //기존에 컨트랙트가 가진 토큰양
        ) public pure returns (uint256) {
            uint256 numerator = outputReserve * inputAmount; //풀 안의 토큰양*내가 넣은 이더양
            uint256 denominator = inputReserve + inputAmount;//풀 안의 이더양+내가 넣은 이더양
            return numerator / denominator;
    }

    //받을 토큰양 정하는 함수 (수수료 부과)
    function getOutputAmount(
		uint256 inputAmount,  //트레이더가 넣은 이더양
        uint256 inputReserve, //기존에 컨트랙트가 가진 이더양
        uint256 outputReserve //기존에 컨트랙트가 가진 토큰양
        ) public pure returns (uint256) {
            uint256 inputAmountWithFee = inputAmount * 99;  
            //1% 수수료를 포함한 트레이더의 입금 이더양 (100개 넣었지만 99개 넣은 것으로 계산, 나머지 1개는 풀에 축적)
            
            uint256 numerator = outputReserve * inputAmountWithFee; //풀 안의 토큰양 * 트레이더가 넣는 수수료 포함 이더양
            uint256 denominator = inputReserve * 100 + inputAmountWithFee;//풀 안의 이더양 * 100 + 트레이더가 넣는 수수료 포함 이더양
            return numerator / denominator;
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

}

