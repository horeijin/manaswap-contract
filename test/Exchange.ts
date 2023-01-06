import { ethers } from "hardhat"
import { expect } from "chai";

import { Exchange } from "../typechain-types/contracts/Exchange"
import { Token } from "../typechain-types/contracts/Token";
import { BigNumber } from "ethers";

const toWei = (value: number) => ethers.utils.parseEther(value.toString());
const toEther = (value: BigNumber) => ethers.utils.formatEther(value);
const getBalance = ethers.provider.getBalance;

describe("Exchange", () => {
    let owner: any;
    let user: any;
    let exchange: Exchange;
    let token: Token;

    beforeEach(async () => {

        //기본적으로 50개의 Ether를 가지고 있음.
        [owner, user] = await ethers.getSigners();
        const TokenFactory = await ethers.getContractFactory("Token");
        token = await TokenFactory.deploy("GrayToken", "GRAY", toWei(10000));
        await token.deployed();

        const ExchangeFactory = await ethers.getContractFactory("Exchange");
        exchange = await ExchangeFactory.deploy(token.address);
        await exchange.deployed();
    });

    //함수(1) 유동성 공급 및 소각 테스트 (기존 토큰 풀이 있을 때 추가 공급)
    describe("removeLiquidity", async () => {
        it("remove liquidity", async () => {
          //기존 유동성 풀 세팅
          await token.approve(exchange.address, toWei(500)); //유동성 공급하기 전에 토큰 500*10^18 wei 승인
          await exchange.addLiquidity(toWei(500), { value: toWei(1000) }); //Exchange 컨트랙트에 작성한 유동성 공급 함수 호출 (마나 토큰 500, 이더 1000) 비율 1:2

          expect(await getBalance(exchange.address)).to.equal(toWei(1000));       //Exchange 컨트랙트가 가진 이더리움 잔액 조회 (0+1000)
          expect(await token.balanceOf(exchange.address)).to.equal(toWei(500));  //Exchange 컨트랙트가 가진 마나토큰 잔액 조회  (0+500)

          //기존 유동성 있는 상태에서 추가 공급
          await token.approve(exchange.address, toWei(100)); //유동성 공급하기 전에 토큰 100*10^18 wei 승인
          await exchange.addLiquidity(toWei(100), { value: toWei(200) }); //Exchange 컨트랙트에 작성한 유동성 공급 함수 호출 (마나토큰 100. 이더 200) 비율 1:2

          expect(await getBalance(exchange.address)).to.equal(toWei(1200));       //Exchange 컨트랙트가 가진 이더리움 잔액 조회 (1000+200)
          expect(await token.balanceOf(exchange.address)).to.equal(toWei(600));  //Exchange 컨트랙트가 가진 마나토큰 잔액 조회 (500+100)

         //유동성 제거
         await exchange.removeLiquidity(toWei(600)); //Exchange 컨트랙트에 작성한 유동성 제거 함수 호출 (lp토큰 600개 반납 = {이더 600:마나토큰 300} 받갰다.)
         expect(await getBalance(exchange.address)).to.equal(toWei(600));       //Exchange 컨트랙트가 가진 이더리움 잔액 조회 (1200-600)
         expect(await token.balanceOf(exchange.address)).to.equal(toWei(300));   //Exchange 컨트랙트가 가진 마나토큰 잔액 조회 (600-300)
        });
    });

    //함수(2) 토큰 가격 조회 테스트
    describe("getTokenPrice", async() => {
        it("correct get Token Price", async() => {
            await token.approve(exchange.address, toWei(1000));
            await exchange.addLiquidity(toWei(1000), { value: toWei(1000) });
            
            const tokenReserve = await token.balanceOf(exchange.address);
            const etherReserve = await getBalance(exchange.address);

            // Mana Price
            // Expect 1ETH per 1GRAY
            expect(
                (await exchange.getPrice(tokenReserve, etherReserve))
            ).to.eq(1);
        })
    })

    //함수(3) 이더->토큰 수수료 포함 스왑 테스트
    describe.skip("SwapWithFee", async() => {
        it("Correct SwapWithFee", async() => {
            await token.approve(user.address, toWei(50)); //컨트랙트 소유자가 가진 50개 이더, 토큰 거래 승인 
            
            //컨트랙트 소유자의 주소로 유동성 공급 (이더 50넣음, 마나토큰 50넣음)
            //지금 소유자는 이제 가진 것 : 이더 0 / 마나토큰 0 / LP토큰(eth-mna) 50
            await exchange.addLiquidity(toWei(50), { value: toWei(50) });

            //트레이더가 스왑 (이더 30넣음, 마나토큰 18.36...가져감)
            //만약 수수료 적용 안하면 마나토큰 18.75... 가져감
            await exchange.connect(user).ethToTokenSwap(toWei(18), { value: toWei(30) });

            //스왑 결과 트레이더의 잔고 (마나토큰 18.63...)
            expect(toEther(await token.balanceOf(user.address)).toString()).to.equal("18.632371392722710163");

            //컨트랙트 소유자의 유동성 제거 (LP토큰 50 반납)
            await exchange.removeLiquidity(toWei(50));

            //유동성 철회 결과 소유자의 마나토큰 잔고 (50 - 18.632371392722710163 = 31.367628607277289837)
            expect(toEther(await token.balanceOf(owner.address)).toString()).to.equal("31.367628607277289837");
        })
    })

    //함수(4) 마나토큰->문스톤토큰 스왑 테스트
    describe("tokenToTokenSwap", async () => {
        it("correct tokenToTokenSwap", async () => {
            //기본적으로 10,000개의 Ether를 가지고 있음.
            [owner, user] = await ethers.getSigners();

            //팩토리 컨트랙트 배포
            const FactoryFactory = await ethers.getContractFactory("Factory");
            const factory = await FactoryFactory.deploy();
            await factory.deployed();

            //create 마나토큰
            const TokenFactory = await ethers.getContractFactory("Token");
            const token = await TokenFactory.deploy("ManaToken", "MNA", toWei(1010));  //1000 + 10(스왑용)
            await token.deployed();

            // create 문스톤토큰
            const TokenFactory2 = await ethers.getContractFactory("Token");
            const token2 = await TokenFactory2.deploy("MoonstoneToken", "MST", toWei(1000));
            await token2.deployed();

            // 마나토큰-이더리움 페어 exchange 컨트랙트 배포
            const exchangeAddress = await factory.callStatic.createExchange(token.address); //callStatic으로 view처럼 exchange 컨트랙트의 주소 가져옴
            await factory.createExchange(token.address);

            // 문스톤토큰-이더리움 페어 exchange 컨트랙트 배포
            const exchange2Address = await factory.callStatic.createExchange(token2.address);
            await factory.createExchange(token2.address);
            
            //유동성 공급
            await token.approve(exchangeAddress, toWei(1000)); //공급 전에 먼저 마나토큰 승인
            await token2.approve(exchange2Address, toWei(1000)); //공급 전에 먼저 문스톤토큰 승인
            const ExchangeFactory = await ethers.getContractFactory("Exchange");
            await ExchangeFactory.attach(exchangeAddress).addLiquidity(toWei(1000), {value: toWei(1000)}) //마나토큰 유동성 공급
            await ExchangeFactory.attach(exchange2Address).addLiquidity(toWei(1000), {value: toWei(1000)})//문스톤토큰 유동성 공급

            // 유동성 공급을 위해 승인 한 1000개를 다 썼으니 스왑을 위해 다시 마나토큰 10개 승인
            await token.approve(exchangeAddress, toWei(10));
            //토큰-토큰 스왑 호출 (마나토큰 10개 넣어서, 문스톤토큰 9개 기대, 이더양도 9개 기대, 문스톤토큰-이더리움 exchange컨트랙트를 통해서...)
            await ExchangeFactory.attach(exchangeAddress).tokenToTokenSwap(toWei(10), toWei(9), toWei(9), token2.address);

            console.log(toEther(await token2.balanceOf(owner.address))); //스왑한 사람이 받길 기대하는 문스톤토큰의 개수 (9개 이상)
            console.log(toEther(await token2.balanceOf(exchangeAddress)));//컨트랙트에서 가지고 있는 문스톤토큰의 개수 (0개)

        });
    });
})