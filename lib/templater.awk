# template a file using something close to mustache templates

function apply_template(rules, template,    cmd, filename) {
	filename = rules["filename"]
	if("converter" in rules){
		cmd = sprintf("%s %s", rules["converter"], filename)
		while ((cmd | getline) > 0)
			print
		close(cmd)
		# else, just output the file
	} else {
		while ((getline < filename) > 0)
			print
	}
}
