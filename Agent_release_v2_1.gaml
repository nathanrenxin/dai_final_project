/**
 *  Agent
 *  Author: ottarg and xin 
 *  Description: sweet stuff
 */


model Agent_release_v2_1


import "building_v2.gaml"

global {
	file building_shapefile <- file("../includes/building.shp");
	geometry shape <- envelope(building_shapefile);
	int max_memory <- 5;
	
	int mapSize_X <- 200;
	int mapSize_Y <- 200;
	int controllerRange <- 50;
	int deliveryRange <- 1;
	map<int,float> deliveryCapacity;
	map<int,float> resourcePrio;
	float supplyStorage<-10000.0;
	
	
	int peopleSpeed_rand <- 2;
	int max_peopleSpeed <- 3;
	float people_size <- 2.0;
	float supplies_size <- 4.0;
	float camp_size <- 4.0;
	float control_size <- 5.0;
	
	int nb_deliveryman<-9;
	int nb_supplies <- 3;
	int nb_camp <-9;
	int nb_requester <- nb_camp;
	int nb_control<-1;
	
	point target_point_avg; 
	point target_point_weigh;
	point target_point_traverse;
	point target_point_norm;
	
	int earthRadius <- 6000;
	point earthCore <- {mapSize_X/2,mapSize_Y/2,-earthRadius};
	
    list<camp> availableCamps;
	list<supplies> availableSupplies;
	
	int scenario_type;
	float restrictionFactor;
	bool staticMap;
	int nb_resourceType <- 2;
	float distanceUtility<-1.0;
	
	string scenario <- "Supplies | Camps | Supplies" among: ["Free for all", "Supplies | Camps", "Camps | Supplies", "Camps | Supplies | Camps", "Supplies | Camps | Supplies"] parameter: true;
	
	bool dayNight_Behaviour <- false;
	int daylight_baseValue <- 90;
	int daylight_differValue <- 50;
	int rate <- 1;
	// Not working???
	int daylight_hour update: dayNight_Behaviour ? daylight_baseValue + daylight_differValue * sin(cycle*rate) : 90; 
	float perc update: dayNight_Behaviour ? (daylight_hour - float(daylight_baseValue-daylight_differValue))/(2*daylight_differValue) :1.0;
	
	init 
	{
		daylight_hour <- 90;
		perc <- 0.5;
		loop i from:1 to: nb_resourceType  
	    { 
          add i::300 to: deliveryCapacity;
          add i::rnd(10)/10 to: resourcePrio;
        }
		// STATIC OBJECTS
		// Create the buildings
		if(staticMap)
		{
			create obsticle from: building_shapefile
			{
				staticBuilding <- staticMap;
				ask cell overlapping self {
					is_obstacle <- true;
					color <- rgb("black");
				}
			}
		}
		else
		{
			list<cell> all_cell <- cell where not (each.is_obstacle);//and each.is_obstacle) ;
			int randomBuildings <- rnd(25) +3;
			create obsticle number: randomBuildings
			{
				staticBuilding <- staticMap;
				
				cell current_cell <- one_of(all_cell);
				location <- current_cell.location;
				int bWidth <- rnd(5) +3;
				int bLength <- rnd(5) +3;
				
				b_width <- bWidth;
				b_length <- bLength;
	    		list<cell> obsCells <- cell where (each.location.x > location.x-bWidth/2 and each.location.x < location.x+bWidth/2
	    			and each.location.y > location.y-bLength/2 and each.location.y < location.y+bLength/2
	    		);
	    		loop aCell over:obsCells{
					aCell.is_obstacle <- true;
					aCell.color <- rgb("black");
				}
			}
		}
		
		// Get all available cells
		list<cell> free_cell <- cell where not (each.is_obstacle);//and each.is_obstacle) ;
		
		// SCENARIO SETUP - hardcoded for now, we only have 5 scenarios
		// 1 is free for all 
		// supplies | camps
		list<cell> _restrictCells <- [];
		if(scenario = "Supplies | Camps")
		{
			write scenario;
			_restrictCells <- (free_cell where (each.location.x < mapSize_X*restrictionFactor));
		}
		
		// camps | supplies
		else if(scenario = "Camps | Supplies")
		//else if(scenario_type = 3)
		{
			write scenario;
			_restrictCells <- (free_cell where (each.location.x > mapSize_X*restrictionFactor));
		}
		// camps | supplies | camps
		else if(scenario = "Camps | Supplies | Camps")
		//else if(scenario_type = 4)
		{
			write scenario;
			float _restrictSplit <- restrictionFactor/2;
			_restrictCells <- (free_cell where (each.location.x > mapSize_X*_restrictSplit and each.location.x < mapSize_X*(1-_restrictSplit)
				and each.location.y > mapSize_Y*_restrictSplit/2 and each.location.y < mapSize_Y*_restrictSplit + mapSize_Y*(1-_restrictSplit)/2
			));
		}
		// supplies | camps | supplies
		else if(scenario =  "Supplies | Camps | Supplies")
		//else if(scenario_type = 5)
		{
			write scenario_type;
			float _restrictSplit <- restrictionFactor/2;
			_restrictCells <- (free_cell where ((each.location.x < mapSize_X*_restrictSplit or each.location.x > mapSize_X*(1-_restrictSplit))
				or (each.location.y < mapSize_Y*_restrictSplit/2 or each.location.y > mapSize_Y*_restrictSplit + mapSize_Y*(1-_restrictSplit)/2)
			));
		}
		// Set all cells found as "is_suppl
		if(not empty(_restrictCells))
		{
			ask _restrictCells 
			{
				is_supply <- true;
				//color <- rgb(229,136,236);
			}
			//_restrictCells <- nil;
			free_cell <- free_cell + _restrictCells;
		}
		else
		{
			_restrictCells <- free_cell;
		}
		
		list<cell> supply_cell <- cell where (each.is_supply);//and each.is_obstacle) ;
		// Create control
		create control number: nb_control
		{
			current_cell <-one_of(free_cell);
			location <- current_cell.location;
			current_cell.is_free <- false;
			size <- control_size;
			
			ask cell overlapping self {
				//color <- rgb(226,126,126);
			}
		}
		
		// Get all supply interiors
		int startX <- 0;
		list<insideCell> buildingCell <- insideCell where not (each.is_obstacle);
		int posAdder <- int(widthX / nb_supplies);
		create insideBuilding number:nb_supplies
		{
			posAdd <- posAdder;
			availableCells <- (buildingCell where (each.location.x < (startX + posAdder) and each.location.x > startX));
			startPositionX <- startX;
			endPositionX <- startX+ posAdder;
			startX <- startPositionX + posAdder;
		}
		availableInteriors <- list<insideBuilding>(insideBuilding);
		//write "found " + availableInteriors.size;
		
		// *** MULTIPLE EDIT
		// Create all resources
		/*int resourceId <- 0;
		create resource number: nb_resourceType
		{
			ID <- resourceId;
			resourceId <- resourceId +1;
			priority <- float((rnd (20))/20); // Maybe just have 20?
		}*/
		
		create supplies number: nb_supplies 
		{
			current_cell <-one_of(_restrictCells);
			location <- current_cell.location;
			current_cell.is_free <- false;
			remove current_cell from: _restrictCells;
			
			// Ref an inside model
			suppyInterior <-one_of(availableInteriors);
			remove suppyInterior from: availableInteriors;

			// Remove all cells in range of supply depoit
			// Make sure no camp is in range of supply
			size <- supplies_size;
			current_cell.is_supply <- true;
			ask cell at_distance controllerRange{//overlapping self {
				is_supply <- true;
				//color <- rgb(229,136,236);
			}
			ask control{
				allsupplies<-allsupplies+myself;
			}
		}
		free_cell <- cell where not (each.is_obstacle or each.is_supply); 
		// Clear memory
		_restrictCells <- nil;
		
		// Create the camps
		create camp number: nb_camp
		{
			current_cell <-one_of(free_cell);
			location <- current_cell.location;
			current_cell.is_free <- false;
			size <- camp_size;
			
			ask cell overlapping self {
				color <- rgb(226,126,126);
			}
		}
		
		availableCamps <- list<camp>(camp);
		availableSupplies <- list<supplies>(supplies);		
		
		create deliveryman number: nb_deliveryman 
		{
			startingSupplies <-one_of(availableSupplies);
			headColor <- startingSupplies.color;
			current_cell <- startingSupplies.current_cell;
			current_cell.is_free <- false;
			remove current_cell from: free_cell;
			location <- current_cell.location;
			speed <- float(rnd(peopleSpeed_rand) + 1);
			memory << current_cell;
			loop aSupplies over:supplies{
				ask aSupplies{
				deliverymen<-deliverymen+myself;
			    } 
			}
		}
		
		create requester number: nb_requester 
		{
			startingCamp <-one_of(availableCamps);
			remove startingCamp from:availableCamps;
			startingCamp <-startingCamp;
			headColor <- startingCamp.color;
			current_cell <- startingCamp.current_cell;
			current_cell.is_free <- false;
			remove current_cell from: free_cell;
			location <- current_cell.location;
			speed <- float(rnd(peopleSpeed_rand) + 1);
			memory << current_cell;
		}
		if(dayNight_Behaviour)
		{
			create earthsimulation number: 1;
		}
		
	}
}



species obsticle 
{
	int depth <- 3 + rnd(5);
	int b_width;
	int b_length;
	bool staticBuilding;
	aspect default 
	{
		if(staticBuilding)
		{
			draw shape color: rgb("gray") depth: depth;
		}
		else
		{
			draw rectangle(b_width,b_length) depth:depth at: location color: #gray  empty: false ;
		}
	}
}

species people skills:[moving, communicating] {
	float size <- people_size;
	cell current_cell;
	cell home_cell;
	list<cell> memory;
	cell target_cell;
	rgb headColor;
	
	init
	{
		// Set the home cell as the starting cell
		home_cell <- current_cell;
		target_cell<-home_cell;
	}
	reflex move_1 when:((current_cell.location distance_to target_cell.location)>speed)
	{
		list<cell> possible_cells <- current_cell neighbours_at speed where (not (each.is_obstacle) and each.is_free and not (each in memory));
		// Keep moving if not there
		if not empty(possible_cells) {
			current_cell.is_free <- true;
			current_cell <- shuffle(possible_cells) with_min_of (each.location distance_to target_cell.location);
			location <- current_cell.location;
			current_cell.is_free <- false;
			memory << current_cell; 
			if (length(memory) > max_memory) {
				remove memory[0] from: memory;
			}
		}
	}
	reflex move_2 when:((current_cell.location distance_to target_cell.location)<=speed and current_cell.location!=target_cell.location)
	{
		current_cell.is_free <- true;
		current_cell <- target_cell;
		location <- current_cell.location;
		current_cell.is_free <- false;
		memory << current_cell; 
		if (length(memory) > max_memory) {
			remove memory[0] from: memory;
		}
	}
}

species requester parent:people {
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
	camp startingCamp;
	// The amount they are currently hold
	//float supplyAmount;
	// Just to make sure we only send a single request. Should implement a FSM for this? State=Monitoring -> State=Requesting...
	bool monitorMode;
	float lowerBound;	
	map<int,float> requestedAmount;
	map<int,float> carryAmount;
	
	//list<resource> resourceNeeded_Info;
		
	init
	{
		write 'requester '+string(self) +' started binding to camp '+ string(startingCamp);
		monitorMode <- true;
		//supplyAmount <- 0.0;
		lowerBound <-rnd (10) / 10;
	}
	
	reflex callForSupplies when: monitorMode 
	{	
		//resourceNeeded_Info <- [];
		
		if(startingCamp.outOfStock)							// *** MULTIPLE EDIT
		{
			loop resc over: startingCamp.resourceStorage
			{
				if(resc.storage < resc.threshHold_level)
				{
					//resource copyResourceInfo <-copy (resc);
					//float newHoldingAmount <- copyResourceInfo.original_storage;
					//copyResourceInfo.holdingAmount <- newHoldingAmount;
					//add copyResourceInfo to: resourceNeeded_Info;
					add resc.ID::resc.original_storage to: requestedAmount;
				}
			}
			monitorMode <- false;
			do send with: [receivers:: control, content:: ['I need supplies.',requestedAmount,lowerBound] ,performative::'request' ,protocol:: 'request_supplies'];
			write 'requester '+string(self) +' sent a message to control center';
		}
		
	}
	
	// Note: will supplyAmount be used anymore?
	reflex requesterToCamp when: !monitorMode and !empty(carryAmount) and current_cell=home_cell
	//reflex requesterToCamp when: !monitorMode and supplyAmount > 0.0 and current_cell=home_cell
	{
		// Must be a better way of finding index, currently O(N^2)
		loop rescID over:carryAmount.keys //startingCamp.resourceStorage
		{
			loop campResc over:startingCamp.resourceStorage
			{
				if(campResc.ID = rescID)
				{
					write "Delivering id " + rescID + " storage " + campResc.storage + " holding " + carryAmount[rescID];
					campResc.storage <- campResc.storage + carryAmount[rescID];
					//resc.holdingAmount <- 0.0;
					//campResc.holdingAmount <- 0.0; 
				}
			}
		}
		//supplyAmount <- float(0);
		monitorMode <- true;
		carryAmount <-nil;
		requestedAmount<-nil;
	}
	reflex handle_reply_from_supplies_1 when: (!empty(informs)) 
	{
		write 'requester '+string(self) +' received a reply from supply station to meet a deliveryman';
		message replyfromsupplies <- informs at 0;
	    deliveryman best_dm <- deliveryman(replyfromsupplies.content at 0);
	    color <-best_dm.color;
	    do send with: [receivers:: [best_dm], content:: ['I need supplies.'] ,performative::'request' ,protocol:: 'request_supplies'];
	    if (!empty(informs) and replyfromsupplies=informs at 0){
	    	remove index:0 from: informs;
	    }
	}
	
	reflex handle_reply_from_supplies_2 when: (!empty(refuses)) 
	{
		write 'requester '+string(self) +' received a reply from supply station to pick up at station';
		message replyfromsupplies <- refuses at 0;
	    supplies closest_supplies <- supplies(replyfromsupplies.content at 0);
	    color <-closest_supplies.color;
	    target_cell <- closest_supplies.current_cell;
	    if (!empty(refuses) and replyfromsupplies=informs at 0){
	    	remove index:0 from: refuses;
	    }
	}
	
	reflex handle_reply_from_deliveryman when: (!empty(proposes)) 
	{
		write 'requester '+string(self) +' received a reply from deliveryman';
		message replyfromdeliveryman <- proposes at 0;
	    target_cell <- cell(replyfromdeliveryman.content at 0);
	    if (!empty(proposes) and replyfromdeliveryman=proposes at 0){
	    	remove index:0 from: proposes;
	    }
	}
	aspect default {
		if(current_cell != home_cell){
		  draw pyramid(size) at: {location.x,location.y,3}  color: headColor;
		  draw sphere(size) at: {location.x,location.y,size} color: color;
		}
	}
}

species deliveryman parent:people {
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
	supplies startingSupplies;
	list<requester> requester_ids;
	map<requester,map<int,float>> requesters;
	meetingpoint mymeetingpoint;
	//float carryAmount;
	//float reservedAmount;
	//float capacity;
	bool is_loading;
	bool is_waiting;
	
	map<int,resource> resourceInfo;
	
	init
	{
		write 'deliveryman '+string(self) +' started binding to supply station '+ string(startingSupplies);
		create meetingpoint number: 1 returns: themeetingpoint
		{
			color <- myself.color;
		}
		mymeetingpoint <-themeetingpoint at 0;
		//carryAmount <- deliveryCapacity;
		//capacity<-deliveryCapacity;
		is_loading<-false;
		is_waiting <- false;
		//reservedAmount <-0.0;
		
		int resourceId <- 1;
		create resource number: nb_resourceType returns: myResouceList // nb_resourceType
		{
			ID <- resourceId;
			priority<-resourcePrio[ID];
			original_storage<-deliveryCapacity[ID];
			holdingAmount<-deliveryCapacity[ID];
			reservedAmount<-0.0;
			resourceId <- resourceId +1;
		}
		loop ars over:myResouceList
		{
			add ars.ID::ars to:resourceInfo;
		}
	}
	
	reflex deliver when: !empty(requester_ids at_distance deliveryRange) // deliveryRange
	{
		ask requester_ids at_distance deliveryRange
		{
			self.carryAmount<-myself.requesters[self];
			self.target_cell <- self.home_cell;
			
			// TODO: What should we do here regarding multiple resources? NOTE: SEE #123 above
			loop rescID over:myself.requesters[self].keys
			{
				myself.resourceInfo[rescID].holdingAmount<-myself.resourceInfo[rescID].holdingAmount-myself.requesters[self][rescID];
				myself.resourceInfo[rescID].reservedAmount<-myself.resourceInfo[rescID].reservedAmount-myself.requesters[self][rescID];
			}
			// get receiver and remove from list
			remove self from: myself.requester_ids;
			remove key: self from: myself.requesters;
		}
	}
	
	reflex travel_back_to_supplies when: empty(requesters) // deliveryRange
	{
		supplies newHome <- supplies closest_to self;
		home_cell <- newHome.current_cell;
		target_cell <-newHome.current_cell;
		mymeetingpoint.mylocation <-nil;
		// Refill supplies when we are empty, near home cell and its not busy
		bool shouldLoad<-false;
		loop rescID over:resourceInfo.keys
		{
			if resourceInfo[rescID].holdingAmount<resourceInfo[rescID].original_storage
			{
				shouldLoad<-true;
			}
		}
		// Add themselfs to the waiting que at home station if they should be loaded, if they are there and they havent already loaded
		if(shouldLoad and (self.location distance_to home_cell.location) < 2 and !is_waiting)// and newHome.loadingDeliveryMan = nil)
		{
			write "load me " + string(self) + " cycle " + cycle + " at station " + string(newHome);
			is_loading <-true;
			is_waiting <- true;
			add self to: newHome.deliverymen_Que;
		}
	}
	
	
	// NOTE: only handle requests when we can deliver?
	reflex handle_request when: (!empty(messages))
	{ 
		write 'deliveryman '+string(self)+' received a message';
	    message requestfromrequester <- messages at 0;
	    requester_ids <- requester_ids+requestfromrequester.sender;
	    
	    list<people> allLocations <- requester_ids+self;
		int n <- length(allLocations);
		int max_speed <- 0;
    	int min_speed <- 1000;
		int total_speed <- 0;
		loop p over:allLocations
		{
			max_speed <- int(max([max_speed, p.speed]));
			min_speed <- int(min([min_speed, p.speed]));
			total_speed <- int(total_speed + p.speed);
		}
		
		float total_factors <- 0.0;
		loop p over:allLocations
		{
			total_factors <- (total_factors+ (total_speed / p.speed));
		}
		
		float avg_x_weigh <- 0.0;
		float avg_y_weigh <- 0.0;
		
		loop p over:allLocations
		{
			avg_x_weigh <- avg_x_weigh + (p.location.x)* weight(p.speed, total_speed, total_factors);
			avg_y_weigh <- avg_y_weigh + (p.location.y)* weight(p.speed, total_speed, total_factors);
		}
		
		// weigh # green
		target_point_weigh <- {avg_x_weigh,avg_y_weigh,0};
		
		// Set the agent target
		// Do net select a meeting point that is an obstacle
		target_cell <- cell where not (each.is_obstacle) closest_to target_point_weigh;
		mymeetingpoint.mylocation <-target_point_weigh;
		do send with: [receivers:: requester_ids, content:: [target_cell] ,performative::'propose' ,protocol:: 'request_supplies'];
	    if (!empty(messages) and requestfromrequester=messages at 0){
	    	remove index:0 from: messages;
	    }
	}
	
	aspect default {
		if(current_cell != home_cell){
		  draw pyramid(size) at: {location.x,location.y,3}  color: headColor;
		  draw circle(size) at: {location.x,location.y,size} color: color;
		}
	}
	
	float weight(float x, int totalSpeed, float totalFactor)
	{
		return  (totalSpeed/x) / totalFactor;
	}
}

species resource
{
	int ID;
	// TODO: chill on the float variables? :Þ
	float priority;
	float storage;
	float consume_rate;
	float threshHold_level;
	float original_storage;
	float weigh <- 0.5; // how heavy each items is
	
	float holdingAmount;
	float reservedAmount;
}

species building
{
	cell current_cell;
	list<cell> memory;
	float size;
	
}

species camp parent:building
{
	rgb color <- rgb("red");
	
	bool outOfStock;// *** MULTIPLE EDIT
	list<resource> resourceStorage;
	
	// We can create with random variables. Just set it here for demonstration
	init
	{
		write 'camp '+string(self) +' started';
		outOfStock <- false;
		int resourceId <- 1;
		create resource number: nb_resourceType returns: myResouceList // nb_resourceType
		{
			ID <- resourceId;
			resourceId <- resourceId +1;
		}
		
		resourceStorage <-  myResouceList;
		// Each camps has different type of storage, consume rate and threshold for each resource
		loop resc over: resourceStorage
		{
			resc.storage <- float(50 + rnd(100));
			resc.original_storage <- resc.storage + 1;
			resc.consume_rate <- 2.0 + (rnd(300)/100) with_precision 2;
			resc.threshHold_level <- 20.0 + rnd(10);
			resc.priority<-resourcePrio[resc.ID];
		}
		
	}
	// TODO: Change the consume rate when camp is at critical level?
	// Only consume supplies at camps when the storage is bigger than the consumption of supplies
	reflex usage //when:  storage > consume_rate
	{
		outOfStock <- false;
		
		
		loop resc over: resourceStorage
		{
			// Uncomment to see the current status of every resource
			//write "camp:" + string(self) + " resource " +  string(resc.ID) + " storage " + resc.storage + " cons " + resc.consume_rate;
			if (resc.storage >resc.threshHold_level)
			{
				resc.storage <- resc.storage - resc.consume_rate*perc;
			}
			else 
			{
				outOfStock <- true;
			}
		}
	}
	aspect default {
		// Green = healthy, red = low on stocks?
		if(!outOfStock){
			draw pyramid(size) at: {location.x,location.y,0} color: rgb("green");
		}
		else{
			// Exclamation mark
			draw square(1) depth:1 at: {location.x,location.y,size+1} color: rgb("red");
			draw square(1) depth:4 at: {location.x,location.y,size+3} color: rgb("red");
			draw pyramid(size) at: {location.x,location.y,0} color: rgb("red");
		}
    }
}

species supplies parent:building skills:[communicating]
{
	list<deliveryman> deliverymen;
	list<deliveryman> deliverymen_Que;
	rgb color <- rgb("blue");
	insideBuilding suppyInterior;
	float storage;
	
	deliveryman loadingDeliveryMan;
	map<requester,map<int,float>> requesters;
	
	int loadStartingCycle;
	
	string supplyType;
	init
	{
		write 'supply station '+string(self) +' started';
		storage <-supplyStorage;
	}
	reflex handle_request when: (!empty(messages)) 
	{
		write 'supply station '+string(self)+' received a message from control center';
	    message requestfromcontrol <- messages at 0;
	    requester from<-requester(requestfromcontrol.content at 0);
	   // float requestedAmount <-float(requestfromcontrol.content at 1);
	    
	    map<int,float> requestedAmounts <- map<int,float>(requestfromcontrol.content at 1);
	    float lowerBound <-float(requestfromcontrol.content at 2);
	    //TODO:
	    map<deliveryman,float> deliverymenUtility<-nil;
	    loop aDeliveryman over:deliverymen
	    {
		    float deliverymanUtility<-0.0;
		    loop rescID over:requestedAmounts.keys{
		    	if requestedAmounts[rescID]<aDeliveryman.resourceInfo[rescID].holdingAmount-aDeliveryman.resourceInfo[rescID].reservedAmount {
		    		deliverymanUtility<-deliverymanUtility+requestedAmounts[rescID]*resourcePrio[rescID];
		        }
		    	else{
		    		deliverymanUtility<-deliverymanUtility+(aDeliveryman.resourceInfo[rescID].holdingAmount-aDeliveryman.resourceInfo[rescID].reservedAmount)*resourcePrio[rescID];
		    	}
		    }
		    if aDeliveryman.target_cell = aDeliveryman.home_cell
		    {
		    	deliverymanUtility <-deliverymanUtility-(from.location distance_to aDeliveryman.location)*distanceUtility;
		    }
		    else
		    {
		    	deliverymanUtility <-deliverymanUtility-(from.location distance_to aDeliveryman.target_cell.location)*distanceUtility;
		    }
		    add aDeliveryman::deliverymanUtility to:deliverymenUtility;	    	
	    }
	    deliveryman best_dm <- deliverymenUtility.keys[0];
	    float highest_dm_utility <- deliverymenUtility[best_dm];
	    loop aDeliveryman over:deliverymenUtility.keys
	    {
	    	if deliverymenUtility[aDeliveryman]>highest_dm_utility
	    	{
	    		best_dm<-aDeliveryman;
	    		highest_dm_utility<-deliverymenUtility[aDeliveryman];
	    	}
	    }
	    float suppliesUtility<-0.0;
		loop rescID over:requestedAmounts.keys{
		    suppliesUtility<-suppliesUtility+requestedAmounts[rescID]*resourcePrio[rescID];
		}
		suppliesUtility <-suppliesUtility-(from.location distance_to location)*distanceUtility;	    
	    if (best_dm=nil or (best_dm!=nil and suppliesUtility>highest_dm_utility)){
		    do send with: [receivers:: from, content:: [self] ,performative::'refuse' ,protocol:: 'request_supplies'];
		    add from::requestedAmounts to: requesters;
		}
		else{	
		    do send with: [receivers:: from, content:: [best_dm] ,performative::'inform' ,protocol:: 'request_supplies'];
		    ask best_dm {
		    	loop rescID over:requestedAmounts.keys{
		    		if requestedAmounts[rescID]<self.resourceInfo[rescID].holdingAmount-self.resourceInfo[rescID].reservedAmount {
		    		    self.resourceInfo[rescID].reservedAmount <-self.resourceInfo[rescID].reservedAmount+requestedAmounts[rescID];
		            }
		    	    else{
		    		    self.resourceInfo[rescID].reservedAmount <-self.resourceInfo[rescID].holdingAmount;
		    		    put self.resourceInfo[rescID].holdingAmount-self.resourceInfo[rescID].reservedAmount at: rescID in: requestedAmounts;
		    	    }
		    	}
		    	add from::requestedAmounts to: self.requesters;
		    }
		}
	    if (!empty(messages) and requestfromcontrol=messages at 0){
	    	remove index:0 from: messages;
	    }
	}
	
	reflex selectDeliveryLoad when: loadingDeliveryMan = nil and !empty(deliverymen_Que)
	{
		write "Supply " + string(self) + " selecting from dm que size " + length(deliverymen_Que);
		// Select the first one
		float utilitySelection <- 0.0;
		deliveryman selectedDm <- nil;
		loop loadDm over: deliverymen_Que
		{
			float dmLoadUtil <- 0.0;
			
			loop resc over: loadDm.resourceInfo
			{
				dmLoadUtil <- dmLoadUtil + (resourcePrio[resc.ID] * resc.holdingAmount) with_precision 2;
				// resc.priority is  resourcePrio[resc.ID]
			}
			
			if(dmLoadUtil > utilitySelection)
			{
				utilitySelection <- dmLoadUtil;
				selectedDm <- loadDm; 
			}
		}
		
		remove selectedDm from: deliverymen_Que;
		
		write "Supply " + string(self) + " selected dm " + string(selectedDm) + " util " + utilitySelection;
		
		loadStartingCycle <- cycle;
		loadingDeliveryMan <- selectedDm;
	}
	
	reflex registerLoading when: loadingDeliveryMan != nil and suppyInterior.isLoading=false
	{
		// How many rounds does it take to load vs each supply station can load at different speed?
		//write "set interior";
		suppyInterior.isLoading <- true;
		suppyInterior.loadingDeliveryMan <-loadingDeliveryMan;
		
		loop rescID over:loadingDeliveryMan.resourceInfo.keys
		{
			add rescID::(loadingDeliveryMan.resourceInfo[rescID].original_storage-loadingDeliveryMan.resourceInfo[rescID].holdingAmount) to: suppyInterior.toload;
		}
	}
	reflex deregisterLoading when: suppyInterior.isLoading 
	{
		bool loadingEnd <-true;
		loop aResourceID over:suppyInterior.toload.keys
		{
			//write "interior " + suppyInterior.toload[aResourceID];
			//write "loaded " + suppyInterior.resourceStorage[aResourceID].loaded;
			if suppyInterior.toload[aResourceID]>suppyInterior.resourceStorage[aResourceID].loaded
			{
				//write "false - cancel load end";
				loadingEnd <-false;
			}
		}
		if loadingEnd
		{
			write "Loaded " + loadingDeliveryMan + " successfully at cycle " + cycle + " from cycle " + loadStartingCycle;
			suppyInterior.isLoading<-false;
			suppyInterior.loadingDeliveryMan<-nil;
			suppyInterior.toload<-nil;
			loop aRescID over:suppyInterior.resourceStorage.keys
			{
				loadingDeliveryMan.resourceInfo[aRescID].holdingAmount<-loadingDeliveryMan.resourceInfo[aRescID].holdingAmount+suppyInterior.resourceStorage[aRescID].loaded;
				suppyInterior.resourceStorage[aRescID].loaded<-0;
				suppyInterior.resourceStorage[aRescID].loading<-0;
				suppyInterior.resourceStorage[aRescID].ontheway<-0;
			}
			loadingDeliveryMan.is_loading<-false;
			loadingDeliveryMan.is_waiting<-false;
			
			loadingDeliveryMan <- nil;
		}
	}
	
	reflex deliver when: !empty(requesters.keys at_distance deliveryRange) // deliveryRange
	{
		ask requesters.keys at_distance deliveryRange
		{
			self.carryAmount<-self.requestedAmount;
			self.target_cell <- self.home_cell;
			// get receiver and remove from list
			remove key: self from: myself.requesters;
		}
	}
	
	aspect default {
		draw pyramid(size) at: {location.x,location.y,0} color: color;
	}
}

species control parent:building skills:[communicating]
{
	list<supplies> allsupplies;
	rgb color <- rgb("black");
	
	init
	{
		write 'supply control center '+string(self) +' started';
	}
	reflex handle_request when: (!empty(messages)) {
		write 'supply control center '+string(self)+' received a message';
	    message requestfromrequester <- messages at 0;
	    supplies best_supplies <- allsupplies closest_to requestfromrequester.sender;
	    map<int,float> requestedAmounts <- map<int,float>(requestfromrequester.content at 1);
	    float lowerBound <-float(requestfromrequester.content at 2);
	    do send with: [receivers:: best_supplies, content:: [requestfromrequester.sender,requestedAmounts,lowerBound] ,performative::'request' ,protocol:: 'request_supplies'];
	    if (!empty(messages) and requestfromrequester=messages at 0){
	    	remove index:0 from: messages;
	    }
	}
	
	aspect default {
		draw pyramid(size) at: {location.x,location.y,0} color: color;
	}
}

species meetingpoint 
{
	rgb color;
	point mylocation;
	
	aspect default{
		if(mylocation != nil)
		{
			draw sphere(1.5 * people_size) at: mylocation color: color;
		}
	}
}

species earthsimulation
{
	point myLocation;
	int centerPos <- mapSize_X/2;
	int elipseFocal_A <- mapSize_X*4 ;
	int elipseFocal_B <- mapSize_X/2 ;
	
	init
	{
		myLocation <- {centerPos + elipseFocal_A * cos(cycle*rate), -1500, elipseFocal_B*sin(cycle*rate) -200};
	}
	reflex update
	{
		myLocation <- {centerPos + elipseFocal_A * cos(cycle*rate), -1500, elipseFocal_B*sin(cycle*rate) -200};
	}
	
	aspect default
	{
		draw sphere(earthRadius) at: earthCore color: rgb(222,184,135);	
		draw sphere(people_size * 8) 
		at: myLocation
		color: rgb("yellow");		
	}
	
}

grid cell width: mapSize_X height: mapSize_Y  neighbours: 8 frequency: 0 {
	bool is_obstacle <- false;
	bool is_supply <- false;
	bool is_free <- true;
	rgb color <- rgb("white");
}

experiment main type: gui {
	
	parameter "Use custom map" var: staticMap <- true;
	parameter "Number of camp" var: nb_camp min: 1 max: 1000;
	parameter "Number of deliveryman" var: nb_deliveryman min: 1 max: 1000;
	parameter "Number of supply station" var: nb_supplies min: 1 max: 1000;
	parameter "Number of resources" var: nb_resourceType min: 1 max: 10;
	
	parameter "Earth + day/night" var: dayNight_Behaviour <- false;
	parameter "Restriction factor" var: restrictionFactor min: 0.0 max: 1.0 <- 0.5;
	output {
		// Inside the loading docks
		display inside_map type: opengl ambient_light: 150  {
			species insideBuilding;
			species staff;
			species resource_storage;
		}
		monitor "Current hour" value: daylight_hour;
		monitor "Perc" value: perc;
		// Change 120 to daylight_hour to use day/night system
		display map type: opengl 
		ambient_light: dayNight_Behaviour ? daylight_hour: 120
		background: dayNight_Behaviour ? rgb(153*perc,204*perc,255*perc) : #white
		{
			//image '../images/ground.jpg';
			//grid cell lines: #red;		// uncomment so see area
			species obsticle refresh: false;
			species camp ;//refresh: false;
			species supplies refresh: false;
			species requester;
			species deliveryman;
			species meetingpoint;
			species control refresh: false;
			species earthsimulation;
		}
	}
}
