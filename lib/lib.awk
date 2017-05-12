# extends arr1 by adding elements of arr2. Assumes numerical array
# returns number of elemns in arr1
function extend(arr1, n1, arr2, n2,    i)
{
    for (i = 1; i <= n2; i++)
        arr1[n1+i] = arr2[i]
    return n1+n2
}

# join elems of array using sep. Assumes numerical array
function join(array, start, stop, sep,    result, i)
{
    result = array[start]
    for (i = start + 1; i <= stop; i++)
        result = result sep array[i]
    return result
}

# converts string containing rules into dict
# note, does not clear out dest array
function rule2array(rule,array,    lines, l, n, sep) {
	split(rule, lines, "\n")

	for (l in lines) {
		l = lines[l]
		n = split(l,sep,"=")
		if(n == 2) {
			array[sep[1]]=sep[2]
		}
	}
}

# removes leading and trailing whitespace
function trim(text) {
	gsub(/^[[:blank:]]*/, "", text)
	gsub(/[[:blank:]]*$/, "", text)
	return text
}

# converts array to a rule string
function array2rule(array,     rule, key) {
	rule = ""
	for (key in array) {
		rule = rule key "=" array[key] "\n"
	}
	return rule
}

# gets the rules that apply to a specific path
# this searches the adt for all rules that apply to this block,
# with more specific rules overriding more general ones
# returns in rules array
function get_rules(adt, path, rules,    path_elems, n, i, key) {
	split("", rules)

	# need to make sure path include current dir in order to match names
	if (path !~ /^\.\//) {
		path = "./" path
	}
	
	n = split(path, path_elems, "/")
	for (i=1; i <= n; i++) {
		key = join(path_elems, 1, i, "/")
		if (key in adt)
			rule2array(adt[key], rules)
	}
}

# checks if array is empty
function is_empty(array,    key) {
	for (key in array) {
		return 0
	}
	return 1
}

# helper function to get all of the rules in adt as string
function dump_rules(adt,    rule_str, r, rule_vals, k) {
	rule_str = ""
	for (r in adt) {
		rule_str = rule_str "[" r "]"
		rule2array(adt[r],rule_vals)
		rule_str = rule_str "\n"
		for (k in rule_vals) 
			rule_str = rule_str  k "=" rule_vals[k] "\n"
	}
	return rule_str
}

# helper function, specifies we have died and prints message to stderr
function die(message) {
	print message >  "/dev/fd/2"
	HAS_DIED="true"
	exit -1
}

# helper function to slurp in all of the text in filename and return as string
function slurp(filename,    text) {
	# if file is empty, just return now
	if ((getline < filename) <= 0)
		return ""
	# otherwise, parse
	text = $0
	while ((getline < filename) > 0)
		text = text "\n" $0
	close(filename)
	return text
}
