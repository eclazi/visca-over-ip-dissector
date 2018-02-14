viscaip_proto = Proto("viscaip", "ViscaIP")

udp_table = DissectorTable.get("udp.port")

visca_command 					= 0x100
visca_inquiry 					= 0x110
visca_reply 					= 0x111
visca_device_setting_command 	= 0x120
control_command 				= 0x200
control_reply	 				= 0x200

payload_type_table = {
	[visca_command] = "VISCA Command",
	[visca_inquiry] = "VISCA Inquiry",
	[visca_reply] = "VISCA Reply",
	[visca_device_setting_command] = "VISCA Device Setting Command",
	[control_command] = "Control Comand",
	[control_reply] = "Control Reply"
}

control_command_reset = 0x01
control_command_error_seq_number = 0x0F01
control_command_error_message = 0x0F01

control_command_table = {
	[control_command_reset] = "RESET",
	[control_command_error_seq_number] = "ERROR Sequence Number",
	[control_command_error_message] = "ERROR Message Abnormality"
}

category_interface = 0x00
category_camera = 0x04
category_pan_tilt = 0x06

category_table = {
	[category_interface] = "Interface",
	[category_camera] = "Camera",
	[category_pan_tilt] = "Pan/Tilt"
}

function viscaip_proto.dissector(buffer, pinfo, tree)
	subtree = tree:add(viscaip_proto, buffer(), "ViscaIP")
	pinfo.cols.protocol = "ViscaIP"

	info_str = ""

	payload_type_buffer = buffer(0, 2)
	payload_type = payload_type_buffer:uint()
	payload_type_str = payload_type_table[payload_type]

	subtree:add(payload_type_buffer, string.format("%s:\t0x%02x", 
		payload_type_str, payload_type))

	info_str = payload_type_str

	payload_length_buffer = buffer(2, 2)
	payload_length = payload_length_buffer:uint()

	subtree:add(payload_length_buffer, string.format("Payload Length:\t%d", payload_length))

	seq_number_buffer = buffer(4, 4)
	seq_number = seq_number_buffer:uint()

	subtree:add(seq_number_buffer, string.format("Sequence Number:\t%d", seq_number))

	info_str = info_str .. string.format(" Seq %d", seq_number)

	if payload_type == control_command then
		control_cmd_buffer = buffer(8, payload_length)
		control_cmd = control_cmd_buffer:uint()
		control_cmd_str = control_command_table[control_cmd]

		subtree:add(control_cmd_buffer, control_cmd_str)
		info_str = info_str .. control_cmd_str
		pinfo.cols.info = info_str
		return
	elseif payload_type == control_reply then
		control_rply_buffer = buffer(8, payload_length)
		subtree:add(control_rply_buffer, "RESET Reply")
		pinfo.cols.info = info_str
		return
	end

    payload_buffer = buffer(8, payload_length)
	
	packet_type_buffer = buffer(8,1)
	packet_type = packet_type_buffer:uint()
	if (bit.band(packet_type, 0xF0) == 0x80) then
		-- command or inquiry
		command_inquiry_buffer = buffer(9, 1)
		command_inquiry = command_inquiry_buffer:uint()
		category_buffer = buffer(10, 1)
		category = category_buffer:uint()

		if command_inquiry == 0x01 then
			-- command
			tree = tree:add(payload_buffer, "Command")
			tree:add(category_buffer, string.format("Category: %s", category_table[category]))
		else
			tree = tree:add(payload_buffer, "Inquiry")
		end
	elseif (bit.band(packet_type, 0xF0) >= 0x90) then

		msg_type_buffer = buffer(9, 1)
		msg_type = msg_type_buffer:uint()
		if (bit.band(msg_type, 0xF0) == 0x40) then
			-- ack
			tree = tree:add(msg_type_buffer, "Acknowledge")
			info_str = info_str .. " Acknowledge"
		elseif (bit.band(msg_type, 0xF0) == 0x50) then
			tree = tree:add(msg_type_buffer, "Completion")
			info_str = info_str .. " Completion"
		elseif (bit.band(msg_type, 0xF0) == 0x60) then
			-- error
			tree = tree:add(msg_type_buffer, "Error")
			info_str = info_str .. " Error"
			socket_buffer = buffer(10, 1)
			socket = bit.band(socket_buffer:uint(), 0x0F)
		 	tree:add(socket_buffer, string.format("Socket: %d", socket))	
		end
	end

	pinfo.cols.info = info_str




	-- -- ID
	-- id = buffer(1, 1)
	-- subtree:add(id, string.format("ID:\t0x%02x", id:uint()))

	-- -- Int24 Fields
	-- info_str = add_int24_field("Pan", subtree, buffer(2, 3))
 --    info_str = info_str .. "\t" ..add_int24_field("Tilt", subtree, buffer(5, 3))
 --    info_str = info_str .. "\t" ..add_int24_field("Roll", subtree, buffer(8, 3))
 --    info_str = info_str .. "\t" ..add_int24_field("X", subtree, buffer(11, 3))
 --    info_str = info_str .. "\t" ..add_int24_field("Y", subtree, buffer(14, 3))
 --    info_str = info_str .. "\t" ..add_int24_field("Z", subtree, buffer(17, 3))
 --    info_str = info_str .. "\t" ..add_int24_field("Zoom", subtree, buffer(20, 3))
 --    info_str = info_str .. "\t" ..add_int24_field("Focus", subtree, buffer(23, 3))

 --    -- Spare
 --    spare = buffer(26, 2)
 --    subtree:add(spare, string.format("Spare:\t0x%04x", spare:uint()))

 --    checksum = buffer(28, 1)
 --    subtree:add(checksum, string.format("Checksum:\t0x%02x", checksum:uint()))

	-- --info_str = string.format("VizRT - Pan %d\tTilt %d\tRoll %d", pan, tilt, roll)
	pinfo.cols.info = info_str

end
udp_table:add(52381, viscaip_proto)
