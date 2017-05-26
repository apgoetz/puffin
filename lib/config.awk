# awk library to parse config file


BEGIN {INI_SEP = ":"}

function unescape(str,   ret, loc) {
	while (length(str) > 0) {
		loc = index(str,"@")
		if (loc == 0) {
			return ret str
		}
		if (loc > 1) {
			ret = ret substr(str, 1, loc-1)
		}

		if (loc == length(str)) {
			die("escape at end of string")
		}
		
		str = substr(str, loc+1)

		if (index(str, "@") == 1) {
			ret = ret "@"
		} else if (index(str, "n") == 1) {
			ret = ret "\n"
		} else die(sprintf("unexpected escape char %s", substr(str,1,1)))

		str = substr(str, 2)
		
	}
	
}

# converts string containing rules into dict
# note, does not clear out dest array
# string must be an ini file fragment
function ini_parsefrag(frag, ini, curkey,   type,l, lines, n, sep, payload, key, num_elem, i) {

	if (frag == "") return

	type = ini_type(frag)

	if (type == "STR") {
		if (curkey="") die("no key specified for STR frag")
		ini[curkey] = ini_val(frag)
	} else if (type == "HASH") {

		split(ini_val(frag), lines, "\n")

		for (l in lines) {
			if (lines[l] == "") continue
			
			n = index(lines[l], "=")
			if (n <= 0) die(sprintf("no = in hash: %s", frag))

			
			payload = substr(lines[l], n+1)
			key = substr(lines[l], 1, n-1)
			
			# unescape newlines
			ini[key] = unescape(payload)
		}
	} else if (type == "ARRAY") {
		num_elem = split(ini_val(frag), lines, "\n")

		i = 0
		for (l = 1; l <= num_elem; l++) {
			if (lines[l] == "") continue

			payload = lines[l]
			
			# unescape newlines
			ini[++i] = unescape(payload)
		}
		ini["_size"] = i # add special variable to count size of array
	}
}

# converts array to a rule string. NOT an ini. 
function ini_arr2frag(array,     frag, key, val, line) {
	frag = "HASH" INI_SEP
	for (key in array) {
		# escape newlines using @ and \n values
		val = array[key]
		gsub("@", "@@", val)
		gsub("\n", "@n", val)
		
		line = key "=" "STR" INI_SEP val "\n"
		frag = frag line
	}
	# if we have added at least one line, we need to chop off the end
	if (line != "") {
		return substr(frag, 1,length(frag)-1)
	} else {
		return frag
	}
}

function ini_numarr2frag(array, n_elems,    i, frag, val, line) {
	frag = "ARRAY" INI_SEP
	for (i = 1; i <= n_elems; i++) {
		# escape newlines using @ and \n values
		val = array[i]
		gsub("@", "@@", val)
		gsub("\n", "@n", val)
		
		line = val "\n"
		frag = frag line
	}
	
	# if we have added at least one line, we need to chop off the end
	if (line != "") {
		return substr(frag, 1,length(frag)-1)
	} else {
		return frag
	}
}


# converts ini to a rule string. NOT a raw array
function ini_ini2frag(array,     frag, key, val, line) {
	frag = "HASH" INI_SEP
	for (key in array) {
		# escape newlines using @ and \n values
		val = array[key]
		gsub("@", "@@", val)
		gsub("\n", "@n", val)
		
		line = key "=" val "\n"
		frag = frag line
	}
	
	# if we have added at least one line, we need to chop off the end
	if (line != "") {
		return substr(frag, 1,length(frag)-1)
	} else {
		return frag
	}
}



# returns string representation of ini file
function ini_print(ini,   key, hashes, arrays, tmp_ini, retval, i) {
	if ("_size" in ini) {
		retval = retval "["
		for (key=1; key <= ini["_size"]; key++) {
			type = ini_type(ini[key])
			if (type == "STR") {
				retval = retval sprintf("\"%s\",", ini_val(ini[key]))
			} else if (type == "HASH" || type == "ARRAY") {
				split("",tmp_ini)
				ini_parsefrag(ini[key],tmp_ini)
				retval = retval sprintf("%s,",ini_print(tmp_ini))
			} else {die(sprintf("Unknown type %s", type))}
		}
		retval = retval "]"
	} else {
		retval = retval "{"
		for (key in ini) {
			type = ini_type(ini[key])
			if (type == "STR") {
				retval = retval sprintf("\"%s\" : \"%s\",", key, ini_val(ini[key]))
			} else if (type == "HASH" || type == "ARRAY") {
				split("",tmp_ini)
				ini_parsefrag(ini[key],tmp_ini)
				retval = retval sprintf("\"%s\" : %s,", key, ini_print(tmp_ini))
			} else {die(sprintf("Unknown type %s", type))}
		}
		retval = retval "}"
	}
	return retval
}

# format of a fragment: TYPE INI_SEP VALUE

# returns the type of a fragment
function ini_type(frag,   i) {
	i = index(frag, INI_SEP)
	if (i == 0) die(sprintf("Expected INI_SEP in fragment: %s", frag))
	return substr(frag, 1, i-1)
}

# returns the value of a fragment
function ini_val(frag,   i) {
	i = index(frag, INI_SEP)
	if (i == 0) die("Expected INI_SEP in fragment")
	return substr(frag, i+1)
}

# gets value of key as number, stored in array as string
function ini_num(ini, key) {
	return ini_str(ini, key)+0
}

# gets value of a key, must be a str
function ini_str(ini, key) {
	if (ini[key] == "")
		return ""

	if (ini_type(ini[key]) != "STR") die(sprintf("Expected STR key in ini: %s", ini[key]))

	return ini_val(ini[key])
}

# get value of hash as array
function ini_hash(ini, key, dest) {

	if (ini[key] == "")
		return

	if (ini_type(ini[key]) != "HASH") die(sprintf("Expected HASH key in ini: %s", ini[key]))

	ini_parsefrag(ini[key], dest)
}

# converts key key of ini into array stored in dest
function ini_array(ini, key, dest) {
	if (ini[key] == "") return

	if (ini_type(ini[key]) != "ARRAY") die(sprintf("Expected ARRAY key in ini: %s", ini[key]))

	ini_parsefrag(ini[key], dest)
}

function ini_add_str(ini, key, val) {
	if (key == "") die("cannot have empty key")
	ini[key] = "STR" INI_SEP val
}

# gets the rules that apply to a specific path
# this searches the adt for all rules that apply to this block,
# with more specific rules overriding more general ones
# returns in rules array
function get_rules(adt, path, rules,    path_elems, n, i, key) {
	split("", rules)

	path = add_curdir(path)
	
	n = split(path, path_elems, "/")
	for (i=1; i <= n; i++) {
		key = join(path_elems, 1, i, "/")
		if (key in adt)
			ini_parsefrag(adt[key], rules)
	}

	# add any rules from the frontmatter
	add_frontmatter(rules, path)
}

function has_frontmatter(filename) {
	return ! system(sprintf("head -c 3 %s 2> /dev/null | grep '+++' > /dev/null 2>&1", filename)) 
}

function add_frontmatter(rules, filename,    keys, n) {

	# check to see if the file has frontmatter
	# frontmatter has magic value +++ as first three bytes of file
	# if it doesn't have this, we can return
	if (! has_frontmatter(filename)) {
		return
	}

	# if we are here, the file has frontmatter, so we need to parse it.
	if ((getline < filename) <= 0 || $0 !~ /^\+\+\+[[:blank:]]*$/) {
		die(sprintf("Invalid frontmatter in %s: %s", filename, $0))
	}

	while (1) {
		if ((getline < filename) <= 0) {
			die(sprintf("Unterminated +++ in frontmatter in %s", filename))
		}
		text = text $0 "\n"
		if ($0 ~ /^\+\+\+[[:blank:]]*$/) {
			break
		}
		
		n = index($0,"=")
		keys[substr($0,1,n-1)] = substr($0, n+1)
	}
	close(filename)

	ini_parsefrag(ini_arr2frag(keys), rules)

	# return number of lines in frontmatter
	return gsub("\\n", "", text) + 2
}

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
	n = index($0, "=")
	key = substr($0, 1, n-1)
	val = substr($0, n+1)
	if (cur_rule_str in adt)
		adt[cur_rule_str] = adt[cur_rule_str] "\n" key "=STR" INI_SEP val
	else
		adt[cur_rule_str] = "HASH" INI_SEP key"=STR" INI_SEP val
}
