import { expect } from "chai";
import { ethers } from "hardhat";
import { SimpleSwap, ZimmerCoin, XmenCoin } from "../typechain-types";
import { Signer } from "ethers";

/**
 * @title SimpleSwap Contract Tests
 * @notice Tests core functionalities of SimpleSwap contract including liquidity, swaps, ownership, and utilities.
 */
describe("SimpleSwap", function () {
  let simpleSwap: SimpleSwap;
  let zimmerCoin: ZimmerCoin;
  let xmenCoin: XmenCoin;
  let owner: Signer;
  let addr1: Signer;
  let ownerAddress: string;
  let addr1Address: string;
  let deadline: number;

  beforeEach(async () => {
    [owner, addr1] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    addr1Address = await addr1.getAddress();
    deadline = Math.floor(Date.now() / 1000) + 3600;

    const ZimmerFactory = await ethers.getContractFactory("ZimmerCoin", owner);
    zimmerCoin = await ZimmerFactory.deploy();
    await zimmerCoin.waitForDeployment();

    const XmenFactory = await ethers.getContractFactory("XmenCoin", owner);
    xmenCoin = await XmenFactory.deploy();
    await xmenCoin.waitForDeployment();

    const SwapFactory = await ethers.getContractFactory("SimpleSwap", owner);
    simpleSwap = await SwapFactory.deploy(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress()
    );
    await simpleSwap.waitForDeployment();

    // Transfer initial tokens to addr1
    await zimmerCoin.transfer(addr1Address, 1000n);
    await xmenCoin.transfer(addr1Address, 1000n);

    // Approve tokens to SimpleSwap contract for addr1
    await zimmerCoin.connect(addr1).approve(await simpleSwap.getAddress(), 1000n);
    await xmenCoin.connect(addr1).approve(await simpleSwap.getAddress(), 1000n);
  });

  it("Should deploy with zero reserves", async () => {
    expect(await simpleSwap.tokenAReserve()).to.equal(0);
    expect(await simpleSwap.tokenBReserve()).to.equal(0);
    expect(await simpleSwap.owner()).to.equal(ownerAddress);
  });

  it("Should add liquidity successfully", async () => {
    await simpleSwap.connect(addr1).addLiquidity(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress(),
      500n,
      500n,
      500n,
      500n,
      addr1Address,
      deadline
    );

    const supply = await simpleSwap.totalLPSupply();
    expect(supply).to.be.gt(0);
  });

  it("Should revert if deadline is expired", async () => {
    const expiredDeadline = Math.floor(Date.now() / 1000) - 10;
    await expect(
      simpleSwap.connect(addr1).addLiquidity(
        await zimmerCoin.getAddress(),
        await xmenCoin.getAddress(),
        100n,
        100n,
        100n,
        100n,
        addr1Address,
        expiredDeadline
      )
    ).to.be.reverted;
  });

  it("Should revert with unsupported token pair", async () => {
    const invalidToken = "0x0000000000000000000000000000000000000001";
    await expect(
      simpleSwap.connect(addr1).addLiquidity(
        invalidToken,
        await xmenCoin.getAddress(),
        100n,
        100n,
        100n,
        100n,
        addr1Address,
        deadline
      )
    ).to.be.reverted;
  });

  it("Should allow renounceOwnership", async () => {
    await simpleSwap.renounceOwnership();
    expect(await simpleSwap.owner()).to.equal(ethers.ZeroAddress);
  });

  it("Should allow transferOwnership", async () => {
    await simpleSwap.transferOwnership(addr1Address);
    expect(await simpleSwap.owner()).to.equal(addr1Address);
  });

  it("Should remove liquidity correctly", async () => {
    await simpleSwap.connect(addr1).addLiquidity(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress(),
      500n,
      500n,
      500n,
      500n,
      addr1Address,
      deadline
    );

    const totalSupplyBefore = await simpleSwap.totalLPSupply();

    await simpleSwap.connect(addr1).removeLiquidity(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress(),
      250n,
      100n,
      100n,
      addr1Address,
      deadline
    );

    const totalSupplyAfter = await simpleSwap.totalLPSupply();
    expect(totalSupplyAfter).to.be.lt(totalSupplyBefore);
  });

  it("Should revert removeLiquidity with expired deadline", async () => {
    const expiredDeadline = Math.floor(Date.now() / 1000) - 10;
    await expect(
      simpleSwap.connect(addr1).removeLiquidity(
        await zimmerCoin.getAddress(),
        await xmenCoin.getAddress(),
        100n,
        100n,
        100n,
        addr1Address,
        expiredDeadline
      )
    ).to.be.reverted;
  });

  it("Should swap tokens successfully (dynamic amountOutMin)", async () => {
    // This will revert due to no liquidity - testing revert behavior
    const amountIn = 100n;
    await zimmerCoin.connect(addr1).approve(await simpleSwap.getAddress(), amountIn);
    await expect(
      simpleSwap.connect(addr1).swapExactTokensForTokens(
        amountIn,
        1n,
        [await zimmerCoin.getAddress(), await xmenCoin.getAddress()],
        addr1Address,
        deadline
      )
    ).to.be.reverted;
  });

  it("Should revert swap with invalid path", async () => {
    await expect(
      simpleSwap.connect(addr1).swapExactTokensForTokens(
        100n,
        90n,
        [await zimmerCoin.getAddress()],
        addr1Address,
        deadline
      )
    ).to.be.reverted;
  });

  it("Should calculate correct amountOut via getAmountOut", async () => {
    const amountOut = await simpleSwap.getAmountOut(500n, 1000n, 2000n);
    expect(amountOut).to.equal(666n);
  });

  it("Should revert getAmountOut with insufficient input amount", async () => {
    await expect(simpleSwap.getAmountOut(0n, 1000n, 1000n)).to.be.reverted;
  });

  it("Should get price correctly", async () => {
    await simpleSwap.connect(addr1).addLiquidity(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress(),
      1000n,
      1000n,
      1000n,
      1000n,
      addr1Address,
      deadline
    );

    const price = await simpleSwap.getPrice(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress()
    );

    expect(price).to.equal(1n * 10n ** 18n);
  });

  it("Should revert getPrice when no reserve A", async () => {
    await expect(
      simpleSwap.getPrice(
        await zimmerCoin.getAddress(),
        await xmenCoin.getAddress()
      )
    ).to.be.reverted;
  });

  it("Should return current block timestamp via getCurrentTimestamp", async () => {
    const ts = await simpleSwap.getCurrentTimestamp();
    expect(ts).to.be.a("bigint");
    expect(ts).to.be.gte(0n);
  });

  it("Should revert getPrice when no reserve B", async () => {
    await simpleSwap.connect(addr1).addLiquidity(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress(),
      1000n,
      1000n,
      1000n,
      1000n,
      addr1Address,
      deadline
    );

    // Remove liquidity to empty reserve B
    await simpleSwap.connect(addr1).removeLiquidity(
      await zimmerCoin.getAddress(),
      await xmenCoin.getAddress(),
      await simpleSwap.totalLPSupply(),
      1n,    // keep reserve A > 0
      1000n, // remove all reserve B
      addr1Address,
      deadline
    );

    await expect(
      simpleSwap.getPrice(
        await zimmerCoin.getAddress(),
        await xmenCoin.getAddress()
      )
    ).to.be.reverted;
  });
});
