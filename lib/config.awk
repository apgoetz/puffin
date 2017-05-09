# awk library to parse config file

# each time we see a new file, store as part of rule name
FNR == 1 {
	
	# get the directory of the current file
	len_file_rule = split(FILENAME,file_rule,"/")
	delete file_rule[len_file_rule]
	len_file_rule--
	file_rule_str = join(file_rule, 1, len_file_rule, "/")
	cur_rule_str = file_rule_str

	# special case: we get passed in the default rules.
	# we set these rules in the global scope
	if (FILENAME == (puf_lib "/puffin.ini")) {
		file_rule_str = "."
		cur_rule_str = "."
	}
}


# if we are in find_sec look for things that match brackets

# remove comment lines
/^[:space:]*#/ {next}

#change rule based on new section encountered
match($0, /\[.*\]/) {
	rulename = substr($0, RSTART+1, RLENGTH-2)
	cur_rule_str = file_rule_str "/" rulename
}

# if we detect a setting of a key value
/.*=.*/ {
	if (cur_rule_str in adt)
		adt[cur_rule_str] = adt[cur_rule_str] "\n" $0
	else
		adt[cur_rule_str] = $0
}
