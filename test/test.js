const { expect } = require("chai");
const { time } = require("@openzeppelin/test-helpers");

describe("Game", () => {

    let owner;
    let alice;
    let bob;
    let res;
    let myntToken;
    let xpToken;
    let game;

    const myntAmount = ethers.utils.parseEther("2500000");
    const ticket = ethers.utils.parseEther("1000");


    beforeEach(async () => {
        xpToken = await ethers.getContractFactory("XP");
        myntToken = await ethers.getContractFactory("Mynt");
        game = await ethers.getContractFactory("Game");
        xpToken = await xpToken.deploy();
        myntToken = await myntToken.deploy();
        await xpToken.deployed();
        await myntToken.deployed();

        [owner, alice, bob] = await ethers.getSigners();
        await Promise.all([
            myntToken.mint(owner.address, myntAmount),
            myntToken.mint(alice.address, myntAmount),
            myntToken.mint(bob.address, myntAmount)
        ]);

        game = await game.deploy(myntToken.address, xpToken.address);
        await game.deployed();

        // Set the first division
        await game.setDivision(1, ethers.utils.parseEther("0"), ethers.utils.parseEther("1000"), "Division 1");

        // Set the first category
        await game.setCategory(1, 1, ticket);

        // Set the second division
        await game.setDivision(2, ethers.utils.parseEther("1000"), ethers.utils.parseEther("10000"), "Division 1");
        // Set the second category with the second division
        await game.setCategory(2, 2, ticket);
    })

    describe("Init", async () => {
        it("should initialize", async () => {
            expect(await xpToken).to.be.ok
            expect(await myntToken).to.be.ok
            expect(await game).to.be.ok
        })
    })

    describe("StartGame", async () => {

        it("A player must first create a match session", async () => {
            let toTransfer = ethers.utils.parseEther("1000")
            await myntToken.connect(alice).approve(game.address, toTransfer)

            expect(await game.gameId())
                .to.eq(0)

            // Alice start a match session with the category 1 and public
            expect(await game.connect(alice).startGame(1, true))
                .to.be.ok

            // the gameId increments after each match creation, the current one should be 1
            expect(await game.gameId())
                .to.eq(1)
        })

        it("should revert with not enough xp", async () => {
            let toTransfer = ethers.utils.parseEther("1000")
            await myntToken.approve(game.address, toTransfer)

            await expect(game.connect(alice).startGame(2, true))
                .to.be.revertedWith("XP Doesn't Match Division")
        })
    })

    describe("Match completion", async () => {
        beforeEach(async () => {
            let toTransfer = ethers.utils.parseEther("1000")
            await myntToken.connect(alice).approve(game.address, toTransfer)
            await game.connect(alice).startGame(1, true)
        })

        it("Another player has to join to complete the match session", async () => {
            let toTransfer = ethers.utils.parseEther("1000")
            await myntToken.connect(bob).approve(game.address, toTransfer)

            // Bob join gameId 1, which was created earlier by alice
            expect(await game.connect(bob).joinGame(1))
                .to.be.ok

        })
    })

    describe("Match Winner detection", async () => {

        let tx;

        beforeEach(async () => {
            let toTransfer = ethers.utils.parseEther("1000")
            await myntToken.connect(alice).approve(game.address, toTransfer)
            await myntToken.connect(bob).approve(game.address, toTransfer)

            await game.connect(alice).startGame(1, true)
            tx = await game.connect(bob).joinGame(1)
            await tx.wait();
            const match = await game.games(1);
            if (match.winner === alice.address) {
                console.log("Winner: ", "Alice");
            }
            else {
                console.log("Winner: ", "Bob");
            }
        })

        it("it should read the event on join game", async () => {

            let receipt = await tx.wait();

            // On GameStarted we set the winner
            let event = receipt.events.find(event => event.event === 'GameStarted');
            const [time, gameId] = event.args;

            const match = await game.games(gameId);

            expect(gameId)
                .to.eq(1)
            // var winAdd = 0;
            // var rand = Math.random();

            // if (rand < 0.5) {
            //     winAdd = match.playerA;
            // }
            // else {
            //     winAdd = match.playerB;
            // }
            // tx = await game.setGameWinner(gameId, winAdd);
            // receipt = await tx.wait();

            // Check if the winner is working 
            // event = receipt.events.find(event => event.event === 'GameFinished');
            // const [winner, _] = event.args;


            // const m = await game.games(gameId);

            // expect(winner)
            //     .to.eq(m.winner)


        })


    })
})