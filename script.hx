DEBUG = {
	MESSAGES: true,
}

var LORE_REWARD = {res:Resource.Lore, amt:60.0, mul:1.0, cb:"chooseLore", name:"Lore"};
var MONEY_REWARD = {res:Resource.Money, amt:50.0, mul:1.0, cb:"chooseMoney", name:"Money"};
var WOOD_REWARD = {res:Resource.Wood, amt:75.0, mul:1.0, cb:"chooseWood", name:"Wood"};
var FOOD_REWARD = {res:Resource.Food, amt:75.0, mul:1.0, cb:"chooseFood", name:"Food"};
var FAME_REWARD = {res:Resource.Fame, amt:30.0, mul:0.5, cb:"chooseFame", name:"Fame"};
var STONE_REWARD = {res:Resource.Stone, amt:8.0, mul:0.75, cb:"chooseStone", name:"Stone"};
var IRON_REWARD = {res:Resource.Iron, amt:5.0, mul:0.75, cb:"chooseIron", name:"Iron"};

var CHOOSE_RES = [
	LORE_REWARD,
	MONEY_REWARD,
	WOOD_REWARD,
	FOOD_REWARD,
	FAME_REWARD,
	STONE_REWARD,
	IRON_REWARD,
];

var VILLAGER_REWARD = {type:Unit.Villager,				amt:3.0, mul:1.5, cb:"chooseVillager", name:"Villagers"};
var WARRIOR_REWARD = {type:Unit.Warrior, 				amt:2.0, mul:1.0, cb:"chooseWarrior", name:"Warriors"};
var AXE_WIELDER_REWARD = {type:Unit.AxeWielder, 		amt:2.0, mul:1.0, cb:"chooseAxeWielder", name:"Axe Wielders"};
var SHIELD_BEARER_REWARD = {type:Unit.ShieldBearer, 	amt:2.0, mul:1.0, cb:"chooseShieldBearer", name:"Shield Bearers"};
var SHEEP_REWARD = {type:Unit.Sheep, 					amt:2.0, mul:2.0, cb:"chooseSheep", name:"Sheep"};

var CHOOSE_UNIT = [
	VILLAGER_REWARD,
	SHEEP_REWARD,
	SHIELD_BEARER_REWARD,
	AXE_WIELDER_REWARD,
	WARRIOR_REWARD,
];

var MAX_YEAR_MUL = 5;

var CHOICE_INDEX = 0;

var ME_ARGS : Array<Dynamic> = [];

var SHEEP_OBJ_ID = "SHEEPSHEEP";
var FAME_OBJ_ID = "FAMEFAME";
var SHEEP_INDEX = 0;
var AI_INDEX = 0;

var winningPlayer:Player = null;
var winningTime = 0.0;
var victoryMessage = "";
var lossMessage = "";

/**
 * Incremented once per call to regularUpdate. Used for sending messages irregularly.
 */
var UPDATE_INDEX = 0;

var playerData : Array<{p:Player, sheeps:Int, resChoices:Array<String>, unitChoices:Array<String>, isDead:Bool}> = [];
var hostPlayer = null;

function init() {
	if (state.time == 0)
		onFirstLaunch();
}

function onFirstLaunch() {
	if(isHost()) {
		hostPlayer = me();

		addRule(Rule.PillarOfGod);
		addRule(Rule.ExtraFoodProduce);

		state.removeVictory(VictoryKind.VLore);
		state.removeVictory(VictoryKind.VFame);
		state.removeVictory(VictoryKind.VMoney);

		for(p in state.players) {
			p.discoverAll();
			playerData.push({p:p, sheeps:0, resChoices:[], unitChoices:[], isDead:false});
			p.objectives.add(FAME_OBJ_ID, "Reach 1500 Fame", {visible:true});
			p.objectives.add(SHEEP_OBJ_ID, "Reach 100 Sheep", {showOtherPlayers:true, goalVal:100, showProgressBar:true, val:0, visible:true});
			p.setAILevel(5); // will be ignored for non-AI players
		}

		for(o in CHOOSE_RES) {
			createButtons(o.name, o.cb, o.amt, o.mul);
		}

		for(o in CHOOSE_UNIT) {
			createButtons(o.name, o.cb, o.amt, o.mul);
		}
	}

	ME_ARGS.push(me());
}

/**
 * Buttons are immutable once created, which is unfortate as we can't indicate to the players
 * how many of each thing they will get by changing the name. Instead, we just create a button
 * for each year.
 */
function createButtons(name:String, cb:String, amt:Float, mul:Float) {
	@sync for(p in state.players) {
		if(p.isAI) {
			continue;
		}
		else {
			p.objectives.add(cb, "Get " + name, {visible:false}, {name:name, action:cb});
		}
	}
}

function regularUpdate(dt : Float) {
	if(isHost()) {
		@split[
			checkVictory(),

			checkNewChoices(),

			checkSheeps(),

			checkAI(),

			checkTheDead(),

			endGame(),
		];
	}

	UPDATE_INDEX++;
}

function endGame() {
	if(winningTime > 0 && winningTime + 10 < state.time) {
		winningPlayer.customVictory(victoryMessage, lossMessage);
	}
}

function findResource(id:String) {
	for(r in CHOOSE_RES) {
		if(r.cb == id){
			return r;
		}
	}

	debug("NOT FOUND RESOURCE!");
	return null;
}

function findUnit(id:String) {
	for(u in CHOOSE_UNIT) {
		if(u.cb == id){
			return u;
		}
	}

	debug("NOT FOUND UNIT!");
	return null;
}

function checkTheDead() {
	@sync for(d in playerData) {
		if(d.isDead)
			continue;
		var found = false;
		for(p in state.players) {
			if(d.p == p)
				found = true;
		}
		if(!found) {
			debug(d.p + " Is dead!");
			d.isDead = true;
		}
	}
}

function checkAI() {

	var data = playerData[AI_INDEX];
	if(data.p.isAI) {
		if(data.resChoices.length > 0) {
			var choice = data.resChoices[randomInt(3)];
			giveResourceReward(data.p, findResource(choice));
		}
		if(data.unitChoices.length > 0) {
			var choice = data.unitChoices[randomInt(3)];
			giveUnitReward(data.p, findUnit(choice));
		}
	}

	AI_INDEX = (AI_INDEX + 1) % 8;
}

function checkSheeps() {
	for(d in playerData) {
		if(d.isDead)
			continue;
		d.sheeps = d.p.capturedUnits.length;
	}
}

/**
 * [Host Only]
 */
function checkVictory() {
	if(winningPlayer != null)
		return;

	for(d in playerData) {
		if(d.isDead)
			continue;
		var fame = d.p.getResource(Resource.Fame);
		var sheeps = d.sheeps;
		if(fame >= 1500) {
			winningPlayer = d.p;
			winningTime = state.time;
			victoryMessage = "You are a very shiny and famous sheep";
			lossMessage = "You were not shiny enough";
			d.p.objectives.setStatus(FAME_OBJ_ID, OStatus.Done);
			d.p.genericNotify("You have won a fame victory! The game will end shortly. TAUNT YOUR ENEMIES! :D");
			for(p in state.players)
				if(p == d.p)
					continue;
				else {
					p.objectives.setStatus(FAME_OBJ_ID, OStatus.Missed);
					p.genericNotify("You have failed to achieve a fame victory! The game will end shortly.");
				}
			break;
		} else if(sheeps >= 100) {
			winningPlayer = d.p;
			winningTime = state.time;
			victoryMessage = "You are a very fluffy sheep";
			lossMessage = "You were not fluffy enough";
			d.p.objectives.setStatus(SHEEP_OBJ_ID, OStatus.Done);
			d.p.genericNotify("YOU LOVE THE SHEEPS! CONGRATS! You are the SHEEPIEST! The game will end shortly.");
			for(p in state.players)
				if(p == d.p)
					continue;
				else {
					p.objectives.setStatus(SHEEP_OBJ_ID, OStatus.Missed);
					p.genericNotify("YOU NO LIKE SHEEP?! TOO BAD YOU LOSE! The game will end shortly.");
				}
			break;
		}
	}

	@sync for(d in playerData) {
		if(d.isDead)
			continue;
		for(other in state.players) {
			if(other == d.p) {
				d.p.objectives.setCurrentVal(SHEEP_OBJ_ID, d.sheeps);
			}
			else {
				other.objectives.setOtherPlayerVal(SHEEP_OBJ_ID, d.p, d.sheeps);
			}
		}
	}
}

/**
 * [Host Only]
 */
function checkNewChoices() {
	if(state.time / 30 > CHOICE_INDEX) {
		CHOICE_INDEX++;

		// decide and show new choices
		@sync for(c in playerData) {
			if(c.isDead)
				continue;

			var player = c.p;

			var oldResChoices = c.resChoices.copy();
			c.resChoices = [];
			var oldUnitChoices = c.unitChoices.copy();
			c.unitChoices = [];

			var resChoices = CHOOSE_RES.copy();
			resChoices = shuffleArray(resChoices);
			for(i in 0...3) {
				var choice = resChoices.pop().cb;
				c.resChoices.push(choice);
				if(!player.isAI){
					player.objectives.setVisible(choice, true);
					if(oldResChoices.indexOf(choice) != -1)
						oldResChoices.remove(choice);
				}
			}

			var unitChoices = CHOOSE_UNIT.copy();
			unitChoices = shuffleArray(unitChoices);
			for(i in 0...3) {
				var choice = unitChoices.pop().cb;
				c.unitChoices.push(choice);
				if(!player.isAI){
					player.objectives.setVisible(choice, true);
					if(oldUnitChoices.indexOf(choice) != -1) {
						oldUnitChoices.remove(choice);
					}
				}
			}

			if(!player.isAI) {
				for(c in oldResChoices){
					player.objectives.setVisible(c, false);
				}
				for(c in oldUnitChoices){
					player.objectives.setVisible(c, false);
				}
			}
		}
	}
}

/**
 * [Host Only]
 */
function clearChoices(p:Player, choices:Array<String>) {
	for(c in choices) {
		p.objectives.setVisible(c, false);
	}
}

function getplayerData(p:Player): {p:Player, resChoices:Array<String>, unitChoices:Array<String>, isDead:Bool} {
	for(c in playerData) {
		if(c.p == p) {
			return c;
		}
	}

	debug("Uhhhhhhhh, this player doesn't exist???");
	return null;
}

/**
 * Returns a whole number of years that have passed.
 */
function timeToYears(time:Float):Int {
	return toInt(time / 720.0) + 1;
}

function computeTotalReward(amt:Float, mul:Float):Int {
	return toInt(amt * timeToYears(state.time) * mul);
}

/**
 * [Host Only]
 */
function giveResourceReward(p:Player, res:{res:ResourceKind, amt:Float, mul:Float, cb:String, name:String}) {
	p.addResource(res.res, computeTotalReward(res.amt, res.mul));
	var data = getplayerData(p);
	if(!p.isAI)
		clearChoices(p, data.resChoices);
	data.resChoices = [];
}

/**
 * [Host Only]
 */
function giveUnitReward(p:Player, unit:{type:UnitKind, amt:Float, mul:Float, cb:String, name:String}) {
	var units = p.getTownHall().zone.addUnit(unit.type, computeTotalReward(unit.amt, unit.mul), p, true);
	var data = getplayerData(p);
	if(!p.isAI)
		clearChoices(p, data.unitChoices);
	data.unitChoices = [];
}

function hostVer(str:String) {
    return str + "_host";
}

// =================== Resource Selection ======================

function chooseIron() {
	invokeHost(hostVer(IRON_REWARD.cb), ME_ARGS);
}

function chooseStone() {
	invokeHost(hostVer(STONE_REWARD.cb), ME_ARGS);
}

function chooseFame() {
	invokeHost(hostVer(FAME_REWARD.cb), ME_ARGS);
}

function chooseFood() {
	invokeHost(hostVer(FOOD_REWARD.cb), ME_ARGS);
}

function chooseWood() {
	invokeHost(hostVer(WOOD_REWARD.cb), ME_ARGS);
}

function chooseMoney() {
	invokeHost(hostVer(MONEY_REWARD.cb), ME_ARGS);
}

function chooseLore() {
	invokeHost(hostVer(LORE_REWARD.cb), ME_ARGS);
}

function chooseIron_host(p:Player) {
	giveResourceReward(p, IRON_REWARD);
}

function chooseStone_host(p:Player) {
	giveResourceReward(p, STONE_REWARD);
}

function chooseFame_host(p:Player) {
	giveResourceReward(p, FAME_REWARD);
}

function chooseFood_host(p:Player) {
	giveResourceReward(p, FOOD_REWARD);
}

function chooseWood_host(p:Player) {
	giveResourceReward(p, WOOD_REWARD);
}

function chooseMoney_host(p:Player) {
	giveResourceReward(p, MONEY_REWARD);
}

function chooseLore_host(p:Player) {
	giveResourceReward(p, LORE_REWARD);
}

// =================== Unit Selection ======================

function chooseWarrior() {
	invokeHost(hostVer(WARRIOR_REWARD.cb), ME_ARGS);
}

function chooseSheep() {
	invokeHost(hostVer(SHEEP_REWARD.cb), ME_ARGS);
}

function chooseShieldBearer() {
	invokeHost(hostVer(SHIELD_BEARER_REWARD.cb), ME_ARGS);
}

function chooseAxeWielder() {
	invokeHost(hostVer(AXE_WIELDER_REWARD.cb), ME_ARGS);
}

function chooseVillager() {
	invokeHost(hostVer(VILLAGER_REWARD.cb), ME_ARGS);
}

function chooseWarrior_host(p:Player) {
	giveUnitReward(p, WARRIOR_REWARD);
}

function chooseSheep_host(p:Player) {
	giveUnitReward(p, SHEEP_REWARD);
}

function chooseShieldBearer_host(p:Player) {
	giveUnitReward(p, SHIELD_BEARER_REWARD);
}

function chooseAxeWielder_host(p:Player) {
	giveUnitReward(p, AXE_WIELDER_REWARD);
}

function chooseVillager_host(p:Player) {
	giveUnitReward(p, VILLAGER_REWARD);
}

function msg(str:String) {
	if(DEBUG.MESSAGES) {
		debug(str);
	}
}