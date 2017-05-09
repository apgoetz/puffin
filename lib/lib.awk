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
	n = split(path, path_elems, "/")
	for (i=1; i <= n; i++) {
		key = join(path_elems, 1, i, "/")
		if (key in adt)
			rule2array(adt[key], rules)
	}
}

# helper function to print all of the rules identified during the configuration
function dump_rules(adt,   r, rule_vals, k) {
	for (r in adt) {
		print "[" r "]"
		rule2array(adt[r],rule_vals)
		for (k in rule_vals) 
			print k "=" rule_vals[k]
	}
}

# helper function, specifies we have died and prints message to stderr
function die(message) {
	print message >  "/dev/fd/2"
	HAS_DIED="true"
	exit -1
}
