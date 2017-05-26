# template a file using something close to mustache templates

# renders content for a file to a string.
# FIXME:
# This function handles rendering a filename. Rendering needs to take
# into account the (optional) converter to use, as well as any
# (optional) frontmatter in the file. Currently, this is handled in a
# hacky way where we count the number of lines of frontmatter and skip
# over that many lines in the renderer. This is to deal with the fact
# that we cannot pipe the contents of a variable into a command in awk
# and then get the results without using gawk's coprocesses, which
# would break compatibility with old awks. The solution is to use tail
# to skip over the first N lines of the output using the optional tail
# -n +N syntax, which is also is not posix compatible
function render_content(rules,     filename, cmd) {
	output = ""
	filename = ini_str(rules,"filename")

	if(has_frontmatter(filename)) {
		num_to_skip = add_frontmatter(rules, filename)
	} else {
		num_to_skip = 0
	}
	
	if("converter" in rules && ini_str(rules,"converter") != ""){
		cmd = sprintf("tail -n +%d %s | %s", num_to_skip, filename, ini_str(rules,"converter"))

		# else, just output the file
	} else {
		cmd = sprintf("tail -n +%d %s", num_to_skip, filename)
	}
	
	return slurp_cmd(cmd)
}


# lex the text inside of a tag. This part is close to an actual lexer
function lex_tag(text, types, tokens, count,      tag_type, token_name) {
	tag_type = substr(text,1,1)
	token_name = ""
	if (tag_type == "!") {
		# comment, don't emit anything
		return count
	} else if (tag_type == "#") {
		token_name = "SECTION"
	} else if (tag_type == "/") {
		token_name = "END"
	} else if (tag_type == "^") {
		token_name = "INVERT"
	} else if (tag_type == ">") {
		token_name = "PARTIAL"
	} else if (tag_type == "{" || tag_type == "&") {
		token_name = "RAWVAR"
	} else if (length(trim(text)) == 0) {
		die("Invalid Empty Tag")
	} else {
		tokens[++count] = trim(text)
		types[count] = "VAR"
		return count
	}

	tokens[++count] = trim(substr(text,2))
	types[count] = token_name
	return count
}

function lexer(template, types, tokens,     len, count, cur_char, unparsed, pre_chars, tag_start, end_regex, tag_len, tag_text, tag_chars) {
	split("",tokens) # clear tokens
	split("",types) # clear types
	len = length(template)
	count = 0
	cur_char = 1
	while (cur_char <= len) {
		unparsed = substr(template, cur_char)
		# Match a tag. Needs to split like this to make non-greedy.
		# Also, need to do this since awk doesn't have match groups
		if (match(unparsed, "{{")) {
			pre_chars = RSTART - 1 # number of chars before tag
			tag_start = RSTART+RLENGTH # where tag inner text starts
			# depending if we are in double or triple curly,
			# the matching regex changes
			if (substr(unparsed, tag_start, 1) == "{") {
				end_regex = "}}}"
			} else {
				end_regex = "}}"
			}
			
			if (match(unparsed, end_regex)) {
				# pull out all of the tag text that is inside,
				# ignoring begining characters from mustache
				tag_len = RSTART - tag_start
				tag_text = substr(unparsed,tag_start,tag_len)
				tag_chars = RLENGTH + RSTART - 1
				
				if (pre_chars > 0) {
					tokens[++count] = substr(unparsed, 1, pre_chars)
					types[count] = "RAW"
				}
				# parse the text in the tag
				count = lex_tag(tag_text, types, tokens, count)
				# update count of processed chars 
				cur_char += tag_chars
			}
		} else {
			# we are at the end. The rest of the text is raw text
			tokens[++count] = unparsed
			types[count] = "RAW"
			
			cur_char = len+1
		}
	}
	return count
}

# token types: RAW SECTION END INVERT PARTIAL VAR RAWVAR

# EBNF OF MUSTACHE

# template = { RAW | VAR | RAWVAR | PARTIAL | block }
# block = ( SECTION | INVERT ) template END .

# determine get_truthiness of section name given a rules structure
function get_truthiness(rules, sec_name,    type) {
	if (!(sec_name in rules)) {
		return 0
	}
	type = ini_type(rules[sec_name])
	if (type == "STR") {
		return ini_val(rules[sec_name])
	} else if (type == "ARRAY") { # if frag value length > 0, that means array has elements, and therefore is true
		return length(ini_val(rules[sec_name]))
	} else if (type == "HASH") {
		return 1
	} else die("Unknown section type")
}


function parser(rules, types, tokens, count, cwd,    retval,i) {

	parse_template(rules, types, tokens, count, cwd, 1, retval)
	
	if (retval["curpos"] <= count) {
		die(sprintf("Could not parse template! Stuck at %s : %s", types[2], tokens[retval["curpos"]]))
		return ""
	} else {
		return retval["result"]
	}
}

function parse_variable(rules, token,     n,sep) {
	# see if this has a dot in it
	n = split(token, sep, ".")
	if (n == 1) {
		if (!(token in rules)) {
			return ""
		} else if (ini_type(rules[token]) == "STR") {
			return ini_str(rules,token)
		} else if (ini_type(rules[token]) == "HASH") {
			return "HASH"
		} else {
			die("Unknown var type in hash")
		}
	} else {
		die(". not allowed in variable at this time")
	}

}

function get_partial_name(partial, cwd) {
	cmd = sprintf("ls %s/%s*", cwd, partial)

	if ((cmd | getline) <= 0) return ""
	close(cmd)
	return $0
}

function parse_template(rules, types, tokens, count, cwd, start, my_retval,      curstring, i, retval) {
	curstring = ""
	i = start
	while (i <= count) {
		if (types[i] == "RAW") {
			curstring = curstring tokens[i]
			i++
		} else if (types[i] == "VAR") {
			curstring = curstring html_escape(parse_variable(rules, tokens[i]))
			i++
		} else if (types[i] == "RAWVAR") {
			curstring = curstring parse_variable(rules, tokens[i])
			i++
		} else if (types[i] == "PARTIAL") {
			curstring = curstring apply_template(rules, tokens[i], cwd)
			i++
		} else if (parse_block(rules, types, tokens, count, cwd, i, retval)) {
			curstring = curstring retval["result"]
			i = retval["curpos"]
		} else {
			break
		}
	}

	my_retval["result"] = curstring
	my_retval["curpos"] = i

	# this template always succeeds
	return 1
}

function parse_block(rules, types, tokens, count, cwd, start, my_retval,  curstring, i, retval, sec_name, end_tok, j, item_rules, limit, type, sec_val) {
	i = start
	curstring = ""

	# parse the rule
	if ((types[i] == "SECTION" || types[i] == "INVERT") && 
	    parse_template(rules, types, tokens, count, cwd, i+1, retval) &&
	    types[retval["curpos"]] == "END") {
		sec_name = trim(tokens[i])
		end_tok = trim(tokens[retval["curpos"]])

		# if block doesn't match, parse error
		if (sec_name != end_tok) {
			die(sprintf("End block does not match section: %s %s", sec_name, end_tok))
		}

		# we are here, block is good, so we can get ready to exit
		my_retval["curpos"] = retval["curpos"] + 1
		
		# FIXME: should be possible to define empty variables
		if (types[start] == "INVERT") {
			if (!get_truthiness(rules, sec_name))
				my_retval["result"] = retval["result"]
			else
				my_retval["result"] = ""
		} else {	# handle regular section
			if (!get_truthiness(rules, sec_name)) {
				my_retval["result"] = ""
			} else { # value exists in hash, so now we decide what to put in.
				type = ini_type(rules[sec_name])
				ini_parsefrag(rules[sec_name], sec_val, "value")
				if (type == "ARRAY") {# special magic variable for now :(
					
					my_retval["result"] = ""
				
					if (ini_str(rules,"limit") != "" && ini_num(rules,"limit") < (sec_val["_size"]+0)) {
						limit = ini_num(rules,"limit")
					} else {
						limit = (sec_val["_size"]+0)
					}
				
					for (j=1; j <= limit; j++) {
						split("", item_rules)
					
						ini_parsefrag(sec_val[j], item_rules)
						if (!parse_template(item_rules, types, tokens, count, cwd, i+1, retval)) die("Error Parsing Item")

						my_retval["result"] = my_retval["result"] retval["result"] 
					}
				} else if (type == "STR") { # we return value of variable
					# if the value is in the rules and is a str type, we don't need to reparse the section in the
					# new context, so the value we got from before is still valid
					my_retval["result"] = retval["result"]
				}
				# on the other hand, if the variable
				# type from before was a hash, we need
				# to rerun the template in the new
				# context in order to see if any other values bubble up
				else if (type == "HASH") {
					# we can move into a hash
					split("",item_rules) # clear tmp rule ini
					acopy(item_rules, rules) # copy over our current context
					ini_hash(item_rules, sec_name, item_rules) # add the rules from the hash key we are entering
					if (!parse_template(item_rules, types, tokens, count, cwd, i+1, retval)) die("Error Parsing Variable")
					my_retval["result"] = retval["result"] 
					
				} else {
					die("Unimplemented")
				}
			}
		}
		return 1
	} else {
		return 0
	}
}

# applys template template using rules rules. returns rendered text
# rules is an array
# template is a filename
# cwd is directory to search for the template, relative to the actual cwd. Defaults to "."
function apply_template(rules, template, cwd,     n, i, tokens, types, cwd_parts, name) {
	# if they didn't set a cwd, use actual cwd
	if (cwd == "") {
		cwd = "."
	}

	# try to find the template in the rules
	if (template in rules) {
		template = rules[template]
	} else { # otherwise, look for it on the filesystem
		name = get_partial_name(template, cwd)
		if (name == "") {
			return ""
		}
		
		n = split((cwd "/" template), cwd_parts, "/")
		cwd = join(cwd_parts, 1, n-1, "/")
		template = slurp(name) # read in whole template
	}

	n = lexer(template, types, tokens)
	return parser(rules, types, tokens, n, cwd)
}
