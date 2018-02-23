//main module starts here
/////////////////////////////////////////////////////////////////////////////////////////////////////
//declaring the input and output ports (outer interface of the program)
// clk 		- 	Zybo clock input
// start	-	Start signal from the user
// stop		-	Stop signal from the user
// push_1	-	Accepts input from the user while playing (acts as left paddle)
// push_2	-	Accepts input from the user while playing (acts as right paddle)
//disp_score-	Displays the score of the user. Its output to be given to seven segment
//				display. The less significant seven bits displays the less significant digit 
//				of user the user score and the later more significant bits displays the second 
//				significant digit of user score
//LED_r		-	Shows the game is currently not ON
//LED_g		-	Shows the game is ON and being played
//LED		- 	Controls the 10 LEDs on the game. At a time one LED glows and resembles a ball
//				moving back and forth
//disp_level-	Displays current level. The output to be given to a seven segment display
//blue		- 	Acts as a paddle. When user gives input the corresponding LEDs on both ends
//				of the above array of ten LEDs glows. Pressing the input at right time (when the 
//				ball reaches at the end) makes user progress through the game. The LSB acts as left
//				paddle and the MSB acts as right paddle
//zybo_LED	-	Controls the four LEDs on the Zybo. (No use now , but helped a lot in debugging)
/////////////////////////////////////////////////////////////////////////////////////////////////////


module Mono_Pong(input clk, input start, input stop, input push_1, input push_2, 
					output [13:0] disp_score, output reg LED_r, output reg LED_g, 
					output reg [9:0] LED, output [6:0] disp_level, output [1:0] blue,
					output [3:0] zybo_LED);
	//declaring intermediate variables (doesn't contribute to external interfaces)
	reg [7:0] score;	//stores players score in BCD form (its basically a counter)
	reg dir;			//controlling direction of the ball. '0' means LEFT and '1' means RIGHT
	wire clock;			//reduced frequency clock according to current "level"
	reg [3:0] level;	//stores current level of the game (also a counter)
	wire push;			//variable which stores user input (paddles) according to 'dir'
	//initialisation of external modules
	clock_generator gen(clk,level,dir,push_1,push_2,clock,push);
	hex_to_sev_seg 	sev_seg_LSB(score[3:0],disp_score[6:0]);
	hex_to_sev_seg 	sev_seg_MSB(score[7:4],disp_score[13:7]);
	hex_to_sev_seg 	sev_seg_level(level[3:0],disp_level[6:0]);
	//combinational section assigning values to outputs
	assign blue[1] = push_2;		//right blue LED
	assign blue[0] = push_1;		//left blue LED
	assign zybo_LED[3] = stop;		//Zybo LED
	assign zybo_LED[2] = start;		//Zybo LED
	assign zybo_LED[1] = push;		//Zybo LED
	assign zybo_LED[0] = push;		//Zybo LED
	//giving initial values to the register variables
	initial 
		begin
			LED_r <= 1'b1;
			LED_g <= 1'b0;
			score <= 8'd0;
			dir <= 1'b0;
			level <= 4'b0;
			LED <= 10'b0;
		end
	always @(posedge clock)
		begin
			//if the game is not in progress accepts user input to start the game
			if(level==4'd0) 
				begin
					//if user has pressed 'start'
					if(start==1'b1)
						begin
							LED_r <= 1'b0;
							LED_g <= 1'b1;
							level <= 4'd1;
							LED <= 10'b0000010000;
							score <= 8'd0;
							dir <= 1'b0;
						end
					//if user hasn't pressed start
					else
						begin
							LED <= 10'b0000000000;
							LED_r <= 1'b1;
							LED_g <= 1'b0;
						end
				end
			//if the game is in progress
			else
				begin
					//user presses 'stop' then stop the game
					if(stop==1'b1)
						begin
							level <= 4'd0;
						end
					else
						//if user hasn't pressed stop and the game is in progress
						//then this block will get executed
						//It controls the ball, score and level
						begin
							//if the ball is going left
							if(dir==1'b0)
								begin
									//move the ball to one unit left
									LED <= LED<<1;
									//if it has reached left end change its direction
									if(LED == 10'b0100000000)
										dir <= 1'b1;
									//if it is on right end it has just started moving left
									//So if user has hit the ball increase his score,change level
									//if it is to be, else stop the game (ie. 'level'=0)
									if(LED == 10'b0000000001)
										begin
											if(push == 1'b1)
												begin
													if(score[3:0]==4'b1001)
														begin
															//since the score is stored as BCD,
															//if less four significant bits are 1001
															//then it is made 0000 and higher significant 
															//bits are increased by one
 															score[7:4] <= score[7:4]+4'b1;
															score[3:0] <= 4'b0;
															//increase level until the user reaches 15th
															//level (impossible to reach) the speed of ball 
															//increases too much to play. So the user looses 
															//in earlier levels
															if(level != 4'b1111)
																level <= level+4'b1;
														end
													else
														score <= score+8'b1;
												end
											else
												level <= 4'b0;
										end
								end
							//if the ball is going right
							if(dir==1'b1)
								begin
									//move the ball to one unit right
									LED <= LED>>1;
									//if it has reached right end change its direction
									if(LED == 10'b0000000010)
										dir <= 1'b0;
									//if it is on left end it has just started moving right
									//So if user has hit the ball increase his score, else stop the game
									//(ie. 'level'=0)
									if(LED == 10'b1000000000)
										begin
											if(push == 1'b1)
												score <= score+8'b1;
											else
												level <= 4'b0;
										end
								end	
						end
				end
		end
endmodule

//module to generate clock used in the game using the Zybo clock and also signals whether the user
//has given right input at right time(swinging of paddle)according to the direction of the ball
/////////////////////////////////////////////////////////////////////////////////////////////////////
//ck	-	Zybo clock input
//level -	Current level of the game (input from previous module)
//drctn	-	Direction of the ball (again input from the previous module)
//push_a-	User input for left paddle
//push_b-	User input for right paddle
//clck	-	Modified output clock according to current level
//push	-	Output to indicate user input
/////////////////////////////////////////////////////////////////////////////////////////////////////


module clock_generator(input ck, input [3:0] level, input drctn, input push_a, input push_b,
						output reg clck, output reg push);
	reg [30:0] tot;			//register variable to store the current threshold value of count
	reg [30:0] count;		//counter to change the frequency of the Zybo input clock
	reg [3:0] push_count;	//a counter to keep track of current postion of the ball
	reg [3:0] prev_level;	//register variable to hold the previous level of the game
							//when current level input from the previous module and 'prev_level'
							//aren't equal then it means level has changed and clock frequency 
							//is to be increased (by decreasing 'tot' 
	reg check_cont_push;	//to defy the smartness of the players
							//if user continuously keeps pressing the input button the this stores 
							//HIGH value and the user input is not accepted and he losts
	//initialising the register variables
	initial 
		begin
			tot <= 31'd0;
			count <= 31'd0;
			clck <= 1'b0;
			push <= 1'b0;
			prev_level <= 4'd0;
			push_count <= 4'd0;
			check_cont_push <= 1'b0;
		end		
	//always executes at the posedge of zybo clock
	always @(posedge ck)
		begin
			//if level has changed
			if(level != prev_level)
				begin
					//make 'prev_level' equal to 'level' so that no duplicate level chenge gets recorded
					prev_level <= level;
					//if current 'level' is zero means game is stopped make tot zero
					//so that the clock output is set at Zybo's clock frequency
					if(level == 4'd0)
						begin
							tot <= 31'd0;
						end
					//if current 'level' is not zero
					else
						begin	
							//if 'level' is one means the game has just started
							//change 'tot' to set the initial speed of ball for first level 
							if(level == 4'd1)
								begin
									tot <= 31'd25000000;	
									push_count <= 4'd5;		//sets current position of ball to fifth position
															//(relative to right paddle
									push <= 1'd0;
								end
							//if 'level' has changed and is not equal to one or zero means game is in progress
							//and user has passed one 'level' so deecrease 'tot' to increase the speed of ball
							else	
								tot <= tot-31'd1562500;
						end
				end
			//if level has not changed
			else
				begin
					//if count has passed the threshold value 'tot' and the level has not changed
					if(count>=tot)
						begin
							//change the level of clock
							clck <= ~clck;
							//make count zero to start counting again
							count <= 31'd0;
							//make push zero so that user input for previous hit doesn't get 
							//double counted as another hit
							push <= 1'b0;
							//if its the positive edge of the clock the current position of ball 
							//would have changed so update it
							if(clck==0)
								begin
									//if ball has reached one end make its positon relative to that
									//end equal to zero
									if(push_count==4'd9)
										begin
										   push_count <= 4'd1;
										end
									//if the ball hasn't reached an end increase its position relative 
									//to the previous end
									else
										begin
										   push_count <= push_count+4'd1;
										end
								end
						end
					//if level has not changed and count has not passed threshold value 
					else
						begin
							count <= count+31'd1;
							//this checks the input of the user and sets the value for 'push' if user
							//has pressed right input according to the direction of the LEDs and also
							//has not been pressing it continuously 
							if((push_count==4'd1) && (check_cont_push==1'b0) && (((drctn==1'b1) && 
										(push_a==1'b1)) || ((drctn==1'b0) && (push_b==1'b1))))
								push <= 1'b1;
						end
				end
		end
	//checks whether or not user has been continuously pressing the inputs when ball reaches the paddle
	//and stores it in 'check_push_cont'
	always @(push_count)
		begin
			if(push_count!=4'd1)
			    begin
			        if(((push_count == 4'd9) && (drctn==1'b0) && (push_a==1'b1)) 
							|| ((push_count == 4'd9) && (drctn==1'b1) && (push_b==1'b1)))
				        check_cont_push <= 1'b1;
			        else
						check_cont_push <= 1'b0;
		        end
		end
endmodule

//module consisting of combination description to convert 4-bit hexadecimal number into 7-bit
//output which can be given to a seven segment display
/////////////////////////////////////////////////////////////////////////////////////////////////////
//out[3:0]  - four bit hexadecimal input
//disp[0]	- a 
//disp[1]	- b 
//disp[2]	- c 
//disp[3]	- d 
//disp[4]	- e 
//disp[5]	- f 
//disp[6]	- g 
/////////////////////////////////////////////////////////////////////////////////////////////////////
module hex_to_sev_seg(input [3:0] out, output [6:0] disp); 
	assign disp[0] = (~out[2] & ~out[0]) | (~out[3] & out[1]) | (~out[3] & out[2] & out[0]) 
						| (out[2] & out[1])	| (out[3] & ~out[2] & ~out[1]) | (out[3] & ~out[0]);
	assign disp[1] = (out[0] & (out[3] ^ out[1])) | (~out[2] & ~out[0]) | (~out[2] & ~out[3])
						| (~out[3] & ~out[1] & ~out[0]);
    assign disp[2] = ~(out[3] | out[1]) | (~(out[3] & out[1]) & out[0]) | (out[3] ^ out[2]);
    assign disp[3] = (~out[3] & ~out[2] & ~out[0]) | (~out[2] & out[1] & out[0])
						| (out[2] & ~out[1] & out[0]) | (out[2] & out[1] & ~out[0]) 
						| (out[3] & ~out[1] & ~out[0]);
    assign disp[4] = (~out[0] & (~out[2] | out[1])) | (out[3] & (out[1] | out[2]));     
    assign disp[5] = (~out[3] & out[2] & ~out[1])  | (~out[1] & ~out[0])  | (out[2] & ~out[0])
						| (out[3] & ~out[2])  | (out[3] & out[1]);
    assign disp[6] = (~out[2] & out[1])  | (out[1] & ~out[0])  | (out[3] & ~out[2])  
						| (out[3] &out[0])	| (~out[3] & out[2] & ~out[1]);
endmodule
