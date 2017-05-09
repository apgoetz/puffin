
# to run this code, use
# awk -E parse.awk $(find . -name puffin.ini | awk '{ print $0 "\t" length($0); }' | sort -k2n | cut  -f1)


END{
	for (rule in adt) {
		print "[" rule "]"
		get_rules(adt, rule, rules)
		for (rule in rules)
			print rule "=" rules[rule]
	}
}
	
