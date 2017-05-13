# template a file using something close to mustache templates

# renders content for a file to a string
function render_content(rules,     output, filename, cmd) {
	output = ""
	filename = rules["filename"]

	if("converter" in rules){
		cmd = sprintf("%s %s", rules["converter"], filename)
		while ((cmd | getline) > 0)
			output = output "\n" $0
		close(cmd)
		# else, just output the file
	} else {
		while ((getline < filename) > 0)
			output = output "\n" $0
	}
	# if we have printed out a line, we need to chomp the first newline
	if (length(output) > 0) return substr(output,2)
	else return output
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


function parser(rules, types, tokens, count, cwd,    retval,i) {

	parse_template(rules, types, tokens, count, cwd, 1, retval)
	if (retval["curpos"] <= count) {
		die(sprintf("Could not parse template! Stuck at %s : %s", types[2], tokens[retval["curpos"]]))
		return ""
	} else {
		return retval["result"]
	}
}

function parse_variable(rules, token) {
	if (token == "Content" && rules["action"] != "list") {
		return render_content(rules)
	} else {
		return rules[token]
	}
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

function parse_block(rules, types, tokens, count, cwd, start, my_retval,  curstring, i, retval, start_tok, end_tok, block_value) {
	i = start
	curstring = ""

	# parse the rule
	if ((types[i] == "SECTION" || types[i] == "INVERT") && 
	    parse_template(rules, types, tokens, count, cwd, i+1, retval) &&
	    types[retval["curpos"]] == "END") {
		start_tok = strip(tokens[i])
		end_tok = strip(tokens[retval["curpos"]])

		# if block doesn't match, parse error
		if (start_tok != end_tok) {
			die(sprintf("End block does not match section: %s %s", start_tok, end_tok))
		}

		# we are here, block is good, so we can get ready to exit
		my_retval["curpos"] = retval["curpos"] + 1
		block_value = parse_variable(rules, start_tok)

		# FIXME: should be possible to define empty variables
		if (types[start] == "INVERT") {
			if (block_value == "")
				my_retval["result"] = retval["result"]
			else
				my_retval["result"] = ""
		} else {	# handle regular section
			if (block_value == "") {
				my_retval["result"] = ""
			} else if (block_value == "Pages") {# special magic variable for now :(
				# FIXME
			} else { # treat as boolean for now
				my_retval["result"] = retval["result"]	
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
function apply_template(rules, template, cwd,     n, i, tokens, types, cwd_parts) {
	# if they didn't set a cwd, use actual cwd
	if (cwd == "") {
		cwd = "."
	}

	# try to find the template in the rules
	if (template in rules) {
		template = rules[template]
	} else { # otherwise, look for it on the filesystem
		n = split((cwd "/" template), cwd_parts, "/")
		cwd = join(cwd_parts, 1, n-1, "/")
		template = slurp(cwd "/" cwd_parts[n] ".mustache") # read in whole template
	}

	n = lexer(template, types, tokens)
	return parser(rules, types, tokens, n, cwd)	
}
