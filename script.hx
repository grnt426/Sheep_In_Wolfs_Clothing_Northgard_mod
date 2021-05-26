/**
 * ===================================
 * 		Sheep in Wolf's Clothing
 *
 * Player's compete on a cut-throat island to determine...who is the fluffiest, most famous
 * sheep in all the land!
 *
 * Every two weeks players can choose between 3 resource rewards and 3 unit rewards. Each year
 * these rewards increase in value. There are no buildings or resources on the map itself
 * other than a few Pillars of Glory, which can be assigned two Heralds for fame.
 *
 * The player who reaches 1500 fame or 100 sheep in their land is the winner!
 * ====================================
 */

/**
 * Used for debugging and testing.
 * All values should be FALSE before publishing to Steam workshop.
 */
DEBUG = {

	// Shows debug messages
	MESSAGES: false,

	// The host starts with lots of units, good for checking for crashes late game.
	PROTECT_HOST: false,

	// Gives the host a lot of resources
	RESOURCES: false,
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

var VILLAGER_REWARD = {type:Unit.Villager,				amt:3.0, cb:"chooseVillager", name:"Villagers"};
var WARRIOR_REWARD = {type:Unit.Warrior, 				amt:2.0, cb:"chooseWarrior", name:"Warriors"};
var AXE_WIELDER_REWARD = {type:Unit.AxeWielder, 		amt:2.0, cb:"chooseAxeWielder", name:"Axe Throwers"};
var SHIELD_BEARER_REWARD = {type:Unit.ShieldBearer, 	amt:2.0, cb:"chooseShieldBearer", name:"Shield Bearers"};
var SHEEP_REWARD = {type:Unit.Sheep, 					amt:2.0, cb:"chooseSheep", name:"Sheep"};
var SPECTER_REWARD = {type:Unit.SpecterWarrior, 		amt:2.0, cb:"chooseSpecterWarrior", name:"Specter Warriors"};
var SKIRMISHER_REWARD = {type:Unit.Skirmisher, 			amt:3.0, cb:"chooseSkirmisher", name:"Skirmishers"};
var KOBOLD_REWARD = {type:Unit.Kobold, 					amt:3.0, cb:"chooseKobold", name:"Kobolds"};

var CHOOSE_UNIT = [
	VILLAGER_REWARD,
	SHEEP_REWARD,
	SHIELD_BEARER_REWARD,
	AXE_WIELDER_REWARD,
	WARRIOR_REWARD,
	SPECTER_REWARD,
	SKIRMISHER_REWARD,
	KOBOLD_REWARD,
];

/**
 * The maximum units that can be sent. This is because drakkar can only
 * send so many units at one time before it crashes.
 */
var MAX_UNIT_SEND = 6;

/**
 * Is used to know when we should refresh the list of choices
 * in a convenient to track way. Also ensures we don't present
 * choices twice in the same increment.
 */
var CHOICE_INDEX = 0;

/**
 * Helper for passing the player into invokeHost calls.
 */
var ME_ARGS : Array<Dynamic> = [];

var SHEEP_OBJ_ID = "SHEEPSHEEP";
var FAME_OBJ_ID = "FAMEFAME";
var SHEEP_INDEX = 0;
var AI_INDEX = 0;

// What year we last updated the mod description in game
var UPDATE_DESC_INDEX = -1;

// The below are used for registering who won, and then delaying
// ending the game for a while so players see that.
var winningPlayer:Player = null;
var winningTime = 0.0;
var victoryMessage = "";
var lossMessage = "";

/**
 * Incremented once per call to regularUpdate. Used for sending messages irregularly.
 */
var UPDATE_INDEX = 0;
var YEAR_INDEX = 0;

var playerData : Array<{p:Player, sheeps:Int, resChoices:Array<String>, unitChoices:Array<String>, isDead:Bool, ocean:Int, resChoiceMade:Bool, unitChoiceMade:Bool}> = [];

/**
 * This is a map of home tiles to oceans next to the home tile. These are used to map Player objects
 * to the appropriate pairing. Once a pairing is made, we can use the drakkar function to
 * send units by boat.
 *
 * Ideally this would be a real Map datastructure, but we still don't have those yet :(
 */
var oceans = [{home:100, ocean:107}, {home:88, ocean:83}, {home:66, ocean:63},
				{home:47, ocean:41}, {home:22, ocean:19}, {home:34, ocean:40},
				{home:55, ocean:62}, {home:77, ocean:84}];

/**
 * Many functions can only be executed by the host, but sometimes we also need to know
 * who the host player is when looping over all players for some one-off exceptions.
 */
var hostPlayer = null;

function init() {
	if (state.time == 0)
		onFirstLaunch();
}

function onFirstLaunch() {

	if(isHost()) {
		hostPlayer = me();

		// Allows assigning Villagers as Heralds at the four Pillars of Glory on the map
		addRule(Rule.PillarOfGod);

		// Makes the townhall produce more food. The values have been edited in the CDB
		addRule(Rule.ExtraFoodProduce);

		// Setup dom only victory
		state.removeVictory(VictoryKind.VLore);
		state.removeVictory(VictoryKind.VFame);
		state.removeVictory(VictoryKind.VMoney);

		// Make all players reveal the map, save their data for later use,
		// create the victory objectives, and if AI, set their diffculty higher
		for(p in state.players) {
			p.discoverAll();
			playerData.push({p:p, sheeps:0, resChoices:[], unitChoices:[], isDead:false, ocean:0, resChoiceMade:false, unitChoiceMade:false});
			p.objectives.add(FAME_OBJ_ID, "Reach 1500 Fame", {visible:true});
			p.objectives.add(SHEEP_OBJ_ID, "Reach 100 Sheep", {showOtherPlayers:true, goalVal:100, showProgressBar:true, val:0, visible:true});
			p.setAILevel(5); // will be ignored for non-AI players
		}

		for(o in CHOOSE_RES) {
			createButtons(o.name, o.cb);
		}

		for(o in CHOOSE_UNIT) {
			createButtons(o.name, o.cb);
		}
	}

	ME_ARGS.push(me());


	// I had a crash that always happened at March 801, and it was frustrating to test.
	// This spawns a ton of units so I can launch the mod and then do anything else for 12
	// minutes to see if it crashed again rather than playing. The AI are really aggressive.
	if(DEBUG.PROTECT_HOST) {
		me().getTownHall().zone.addUnit(Unit.Warrior, 30, me());
		me().getTownHall().zone.addUnit(Unit.Villager, 30, me());
	}

	// Used for testing crashes, tech, and more
	if(DEBUG.RESOURCES) {
		me().addResource(Resource.Wood, 10000);
		me().addResource(Resource.Lore, 10000);
		me().addResource(Resource.Food, 2000);
	}
}

/**
 * This will update the description of the mod under the Victory window.
 *
 * It will also show a list of reward values for resources and units,
 * as that changes each year.
 */
function updateDescriptionOfMod() {
	if(UPDATE_DESC_INDEX >= timeToYears(state.time)) {
		return;
	}

	UPDATE_DESC_INDEX++;

	state.scriptDesc =
		"<p>"
			+ "Your goal is to be the most famous and fluffy sheep in all the land! Ok, well, you do not have to be both, but that be cool, right? You win if you get 100 sheep or 1500 fame."
		+ "</p>"
		+ "<br />"
		+ "<p align='center'><font face='BigTitle'>Current Rewards</font></p>"
		+ "<p><font face='Title'>Resources</font></p>"
		+ "<p>"
	;

	for(r in CHOOSE_RES){
		state.scriptDesc += "<b>" + r.name + ":</b> " + computeTotalReward(r.amt, r.mul, false) + "<br />";
	}

	state.scriptDesc +=
		"</p>"
		+ "<br />"
		+ "<p><font face='Title'>Units</font></p>"
		+ "<p>"
	;

	for(u in CHOOSE_UNIT){
		state.scriptDesc += "<b>" + u.name + ":</b> " + computeTotalReward(u.amt, 0, true) + "<br />";
	}

	state.scriptDesc += "</p>";

	for(p in state.players)
		p.genericNotify("Check the victory screen for updated reward amounts each year!");
}

/**
 * Buttons are immutable once created, which is unfortate as we can't indicate to the players
 * how many of each thing they will get by changing the name. Instead, we just create a button
 * for each year.
 */
function createButtons(name:String, cb:String) {
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
			setupOceans(),

			checkVictory(),

			checkNewChoices(),

			checkSheeps(),

			checkTheDead(),

			endGame(),

			updateDescriptionOfMod(),
		];
	}

	UPDATE_INDEX++;
}

/**
 * Here we do a one time mapping of players to their home tile ID and the neighboring
 * ocean where we will send drakkar ships of units from.
 */
function setupOceans() {
	if(playerData[0].ocean != 0)
		return;

	for(d in playerData) {
		var ocean = 0;
		msg("Getting ocean for " + d.p);
		for(o in oceans) {
			if(o.home == d.p.getTownHall().zone.id) {
				msg("Getting ocean: " + o.ocean);
				d.ocean = o.ocean;
				break;
			}
		}
	}
}

/**
 * If someone won the game, we wait a short time before ending
 * the game for everyone so players have a chance to see who won
 * and trash talk :P
 */
function endGame() {
	if(winningTime > 0 && winningTime + 10 < state.time) {
		winningPlayer.customVictory(victoryMessage, lossMessage);
	}
}

/**
 * Given a resource name, will find the respective resource reward struct.
 */
function findResource(id:String) {
	for(r in CHOOSE_RES) {
		if(r.cb == id){
			return r;
		}
	}

	msg("NOT FOUND RESOURCE!");
	return null;
}

/**
 * Given a unit name, will find the respective unit reward struct.
 */
function findUnit(id:String) {
	for(u in CHOOSE_UNIT) {
		if(u == null) {
			msg("why is find unit null?");
			return null;
		}
		if(u.cb == id){
			return u;
		}
	}

	msg("NOT FOUND UNIT!");
	return null;
}

/**
 * Checks for dead players, as we have no easy way to see who lost.
 * We do this by checking against state.players, as defeated players
 * are removed.
 */
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
			msg(d.p + " Is dead!");
			d.isDead = true;
		}
	}
}

/**
 * [Host Only]
 *
 * If there are any AI, each update one of the 8 players will be checked.
 * If they are an AI that is alive and they have unused choices to make they
 * will make one of those choices.
 */
function checkAI() {

	var data = playerData[AI_INDEX];
	if(data.p.isAI && !data.isDead) {
		if(data.resChoices.length > 0) {
			var choice = data.resChoices[randomInt(3)];
			giveResourceReward(data.p, findResource(choice));
		}

		if(data.unitChoices.length > 0) {
			var choice = data.unitChoices[math.irandom(3)];
			giveUnitReward(data.p, findUnit(choice));
		}
	}

	AI_INDEX = (AI_INDEX + 1) % 8;
}

/**
 * If a player isn't dead, then we update their sheeps total
 */
function checkSheeps() {
	for(d in playerData) {
		if(!d.isDead)
			d.sheeps = d.p.capturedUnits.length;
	}
}

/**
 * [Host Only]
 *
 * Checks to see if any player has reached the threshold for victory in sheep or fame.
 * If no player has, then we just update the objectives progression.
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
			d.p.genericNotify("You have won a fame victory! TAUNT YOUR ENEMIES! :D The game will end shortly.");
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
 *
 * We present 3 resource rewards and 3 unit rewards to all players every 30 seconds.
 * The rewards choices are random.
 */
function checkNewChoices() {
	if(state.time / 30 > CHOICE_INDEX) {

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

			// allow the player to make a new choice
			c.unitChoiceMade = false;
			c.resChoiceMade = false;
		}
	}

	checkAI();
}

/**
 * [Host Only]
 *
 * Sets all the choices a player had not visible so they can't keep pressing the button.
 */
function clearChoices(p:Player, choices:Array<String>) {
	for(c in choices) {
		p.objectives.setVisible(c, false);
	}
}

/**
 * Given a player object, will return the PlayerData struct mapped to that player.
 */
function getplayerData(p:Player): {p:Player, resChoices:Array<String>, unitChoices:Array<String>, isDead:Bool, ocean:Int, resChoiceMade:Bool, unitChoiceMade:Bool} {

	if(p == null) {
		msg("Why were we passed a null player?");
		return null;
	}

	for(c in playerData) {
		if(c == null){
			msg("Uhhh, why is getPlayedData null?");
			return null;
		}
		if(c.p == p) {
			return c;
		}
	}

	msg("Uhhhhhhhh, this player doesn't exist???");
	return null;
}

/**
 * Returns a whole number of years that have passed.
 */
function timeToYears(time:Float):Int {
	return toInt(time / 720.0);
}

/**
 * Just applies all the various parameters to determine how much of something
 * the player should get.
 */
function computeTotalReward(amt:Float, mul:Float, isUnits:Bool):Int {
	return isUnits ? min(MAX_UNIT_SEND, toInt(amt + timeToYears(state.time))) : toInt(amt * (timeToYears(state.time) + 1) * mul);
}

/**
 * [Host Only]
 *
 * Gives the player the reward of resources they had chosen.
 * Will also prevent the reward button from triggering more than once.
 */
function giveResourceReward(p:Player, res:{res:ResourceKind, amt:Float, mul:Float, cb:String, name:String}) {
	var data = getplayerData(p);

	// Players can press the button rapidly to send multiple requests. We guard against that here
	if(data.resChoiceMade)
		return;
	data.resChoiceMade = true;

	// Add the resources, clear the shown objectives, and then empty the choices list
	p.addResource(res.res, computeTotalReward(res.amt, res.mul, false));
	if(!p.isAI)
		clearChoices(p, data.resChoices);
	data.resChoices = [];
}

/**
 * [Host Only]
 *
 * Gives the player the reward of units they had chosen.
 * Will also prevent the reward button from triggering more than once.
 */
function giveUnitReward(p:Player, unit:{type:UnitKind, amt:Float, cb:String, name:String}) {
	var data = getplayerData(p);

	if(unit == null) {
		msg("Something went wrong, we got a null unit?");
		return;
	}

	if(data == null) {
		msg("Something went wrong, we got a null player data?");
		return;
	}

	// Players can press the button rapidly to send multiple requests. We guard against that here
	if(data.unitChoiceMade)
		return;
	data.unitChoiceMade = true;

	var total = computeTotalReward(unit.amt, 0, true);
	var units = [];
	while(total > 0) {
		units.push(unit.type);
		total--;
	}
	drakkar(p, p.getTownHall().zone, getZone(data.ocean), 0, 0, units, 0.15);

	if(!p.isAI)
		clearChoices(p, data.unitChoices);
	data.unitChoices = [];
}

function hostVer(str:String) {
    return str + "_host";
}

// =================== Resource Selection ======================
// TODO: this could and should be compressed. While the
// "chooseX" functions have to exist, the "chooseX_host" really
// only needs one function. I was lazy when setting this up.

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

function chooseSpecterWarrior() {
	invokeHost(hostVer(SPECTER_REWARD.cb), ME_ARGS);
}

function chooseSkirmisher() {
	invokeHost(hostVer(SKIRMISHER_REWARD.cb), ME_ARGS);
}

function chooseKobold() {
	invokeHost(hostVer(KOBOLD_REWARD.cb), ME_ARGS);
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

function chooseSpecterWarrior_host(p:Player) {
	giveUnitReward(p, SPECTER_REWARD);
}

function chooseKobold_host(p:Player) {
	giveUnitReward(p, KOBOLD_REWARD);
}

function chooseSkirmisher_host(p:Player) {
	giveUnitReward(p, SKIRMISHER_REWARD);
}

/**
 * This allows me to keep the debug messages in code,
 * and also publish the mod to the steam workshop while
 * only changing a DEBUG flag to prevent players from
 * seeing annoying messages.
 */
function msg(str:String) {
	if(DEBUG.MESSAGES) {
		debug(str);
	}
}

/**
 * Some debug messages need to print, but I don't want them
 * to print every single update as that would be annoying.
 * This slows the print rate to a much smaller degree.
 */
function sometimesMsg(str:String) {
	if(DEBUG.MESSAGES && UPDATE_INDEX % 5 == 0) {
		debug(str);
	}
}