# helper func to get rules that apply to a given file

END {

	if (HAS_DIED=="true") {
		exit -1
	}

	get_rules(adt, filename, rules)
	add_autovars(rules, filename)
	print ini_print(rules)
}
