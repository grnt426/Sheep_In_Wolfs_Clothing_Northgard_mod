DEBUG = {
	MESSAGES: true,
}

var LORE_REWARD = {res:Resource.Lore, amt:60.0, mul:1.0, cb:"chooseLore", name:"Lore"};
var MONEY_REWARD = {res:Resource.Money, amt:50.0, mul:1.0, cb:"chooseMoney", name:"Money"};
var WOOD_REWARD = {res:Resource.Wood, amt:75.0, mul:1.0, cb:"chooseWood", name:"Wood"};
var FOOD_REWARD = {res:Resource.Food, amt:75.0, mul:1.0, cb:"chooseFood", name:"Food"};
var FAME_REWARD = {res:Resource.Fame, amt:60.0, mul:1.0, cb:"chooseFame", name:"Fame"};
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

var playerData : Array<{p:Player, sheeps:Int, resChoices:Array<String>, unitChoices:Array<String>}> = [];
var hostPlayer = null;

function init() {
	if (state.time == 0)
		onFirstLaunch();
}

function onFirstLaunch() {
	if(isHost()) {
		hostPlayer = me();

		addRule(Rule.PillarOfGod);
		addRule(Rule.PurchaseTechWithKrowns);
		addRule(Rule.DefendedTownhalls);
		addRule(Rule.ExtraFoodProduce);

		state.removeVictory(VictoryKind.VLore);
		state.removeVictory(VictoryKind.VFame);
		state.removeVictory(VictoryKind.VMoney);

		for(p in state.players) {
			p.discoverAll();
			playerData.push({p:p, sheeps:0, resChoices:[], unitChoices:[]});
		}

		state.objectives.add(FAME_OBJ_ID, "Reach 1500 Fame");
		state.objectives.add(SHEEP_OBJ_ID, "Reach 100 Sheep", {showOtherPlayers:true, goalVal:100});

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
		];
	}
}

function checkSheeps() {
	var data = playerData[SHEEP_INDEX];
	data.sheeps = 0;
	var player = data.p;

	// TODO can wolf capture anything else on this tiny map? If not, then just getting
	// the length of this will save a lot of time
	for(u in player.capturedUnits) {
		if(u.kind == Unit.Sheep) {
			data.sheeps++;
		}
	}
	SHEEP_INDEX = (SHEEP_INDEX + 1) % 8;
}

/**
 * [Host Only]
 */
function checkVictory() {
	for(d in playerData) {
		var fame = d.p.getResource(Resource.Fame);
		var sheeps = d.sheeps;
		if(fame >= 1500) {
			d.p.customVictory("You are a very shiny and famous sheep", "You were not shiny enough");
		} else if(sheeps >= 100) {
			d.p.customVictory("You are a very fluffy sheep", "You were not fluffy enough");
		}

		if(d.p != hostPlayer)
			state.objectives.setOtherPlayerVal(SHEEP_OBJ_ID, d.p, sheeps);
		else
			state.objectives.setCurrentVal(SHEEP_OBJ_ID, sheeps);
	}
}

/**
 * [Host Only]
 */
function checkNewChoices() {
	if(state.time / 30 > CHOICE_INDEX) {
		msg("Clearing choices and setting up the next round");
		CHOICE_INDEX++;

		// decide and show new choices
		@sync for(c in playerData) {
			var player = c.p;
			if(player.isAI)
				continue;

			var oldResChoices = c.resChoices.copy();
			c.resChoices = [];
			var oldUnitChoices = c.unitChoices.copy();
			c.unitChoices = [];

			var resChoices = CHOOSE_RES.copy();
			resChoices = shuffleArray(resChoices);
			for(i in 0...3) {
				var choice = resChoices.pop().cb;
				c.resChoices.push(choice);
				player.objectives.setVisible(choice, true);
				if(oldResChoices.indexOf(choice) != -1)
					oldResChoices.remove(choice);
			}

			var unitChoices = CHOOSE_UNIT.copy();
			unitChoices = shuffleArray(unitChoices);
			for(i in 0...3) {
				var choice = unitChoices.pop().cb;
				c.unitChoices.push(choice);
				player.objectives.setVisible(choice, true);
				if(oldUnitChoices.indexOf(choice) != -1) {
					oldUnitChoices.remove(choice);
				}
			}

			for(c in oldResChoices){
				player.objectives.setVisible(c, false);
			}
			for(c in oldUnitChoices){
				player.objectives.setVisible(c, false);
			}
		}
	}
}

/**
 * [Host Only]
 */
function clearChoices(p:Player, choices:Array<String>) {
	debug("Clearing choices");
	for(c in choices) {
		p.objectives.setVisible(c, false);
		debug("Cleared: " + c);
	}
}

function getplayerData(p:Player): {p:Player, resChoices:Array<String>, unitChoices:Array<String>} {
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
	debug("COMPUTING YEARS, I GUESS");
	return toInt(time / 720.0) + 1;
}

function computeTotalReward(amt:Float, mul:Float):Int {
	return toInt(amt * timeToYears(state.time) * mul);
}

/**
 * [Host Only]
 */
function giveResourceReward(p:Player, res:{res:ResourceKind, amt:Float, mul:Float, cb:String, name:String}) {
	msg("Giving a player a resource reward");
	p.addResource(res.res, computeTotalReward(res.amt, res.mul));
	var data = getplayerData(p);
	clearChoices(p, data.resChoices);
	data.resChoices = [];
}

/**
 * [Host Only]
 */
function giveUnitReward(p:Player, unit:{type:UnitKind, amt:Float, mul:Float, cb:String, name:String}) {
	msg("Giving a player unit reward");
	var units = p.getTownHall().zone.addUnit(unit.type, computeTotalReward(unit.amt, unit.mul), p, true);
	var data = getplayerData(p);
	clearChoices(p, data.unitChoices);
	data.unitChoices = [];
}

function hostVer(str:String) {
    return str + "_host";
}

// =================== Resource Selection ======================

function chooseIron() {
	if(me() == hostPlayer){
		chooseIron_host(me());
	}
	else
		invokeHost(hostVer(IRON_REWARD.cb), ME_ARGS);
}

function chooseStone() {
	if(me() == hostPlayer){
		chooseStone_host(me());
	}
	else
		invokeHost(hostVer(STONE_REWARD.cb), ME_ARGS);
}

function chooseFame() {
	if(me() == hostPlayer){
		chooseFame_host(me());
	}
	else
		invokeHost(hostVer(FAME_REWARD.cb), ME_ARGS);
}

function chooseFood() {
	debug("FOOD CLICKED");
	if(me() == hostPlayer){
		chooseFood_host(me());
	}
	else{
		invokeHost(hostVer(FOOD_REWARD.cb), ME_ARGS);
	}
}

function chooseWood() {
	debug("WOOD CLICKED");
	if(me() == hostPlayer){
		chooseWood_host(me());
	}
	else
		invokeHost(hostVer(WOOD_REWARD.cb), ME_ARGS);
}

function chooseMoney() {
	debug("MONEY CLICKED");
	if(me() == hostPlayer){
		chooseMoney_host(me());
	}
	else
		invokeHost(hostVer(MONEY_REWARD.cb), ME_ARGS);
}

function chooseLore() {
	if(me() == hostPlayer){
		chooseLore_host(me());
	}
	else
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
	if(me() == hostPlayer){
		chooseWarrior_host(me());
	}
	else
		invokeHost(hostVer(WARRIOR_REWARD.cb), ME_ARGS);
}

function chooseSheep() {
	debug("SHEEP CLICKED");
	if(me() == hostPlayer){
		chooseSheep_host(me());
	}
	else
		invokeHost(hostVer(SHEEP_REWARD.cb), ME_ARGS);
}

function chooseShieldBearer() {
	if(me() == hostPlayer){
		chooseShieldBearer_host(me());
	}
	else
		invokeHost(hostVer(SHIELD_BEARER_REWARD.cb), ME_ARGS);
}

function chooseAxeWielder() {
	if(me() == hostPlayer){
		chooseAxeWielder_host(me());
	}
	else
		invokeHost(hostVer(AXE_WIELDER_REWARD.cb), ME_ARGS);
}

function chooseVillager() {
	if(me() == hostPlayer){
		chooseVillager_host(me());
	}
	else
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