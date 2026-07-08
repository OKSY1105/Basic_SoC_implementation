
//input ports
add mapped point i_input[3] i_input[3] -type PI PI
add mapped point i_input[2] i_input[2] -type PI PI
add mapped point i_input[1] i_input[1] -type PI PI
add mapped point i_input[0] i_input[0] -type PI PI

//output ports
add mapped point o_output[6] o_output[6] -type PO PO
add mapped point o_output[5] o_output[5] -type PO PO
add mapped point o_output[4] o_output[4] -type PO PO
add mapped point o_output[3] o_output[3] -type PO PO
add mapped point o_output[2] o_output[2] -type PO PO
add mapped point o_output[1] o_output[1] -type PO PO
add mapped point o_output[0] o_output[0] -type PO PO

//inout ports




//Sequential Pins
add mapped point o_output[0]/q o_output_reg[0]/Q -type DLAT DLAT
add mapped point o_output[2]/q o_output_reg[2]/Q -type DLAT DLAT
add mapped point o_output[3]/q o_output_reg[3]/Q -type DLAT DLAT
add mapped point o_output[6]/q o_output_reg[6]/Q -type DLAT DLAT
add mapped point o_output[1]/q o_output_reg[1]/Q -type DLAT DLAT
add mapped point o_output[4]/q o_output_reg[4]/Q -type DLAT DLAT
add mapped point o_output[5]/q o_output_reg[5]/Q -type DLAT DLAT



//Black Boxes



//Empty Modules as Blackboxes
