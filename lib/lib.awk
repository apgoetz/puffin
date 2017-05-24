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

# removes leading and trailing whitespace
function trim(text) {
	gsub(/^[[:blank:]]*/, "", text)
	gsub(/[[:blank:]]*$/, "", text)
	return text
}



# checks if array is empty
function is_empty(array,    key) {
	for (key in array) {
		return 0
	}
	return 1
}


# helper function, specifies we have died and prints message to stderr
function die(message) {
	print message | "cat 1>&2"
	HAS_DIED="true"
	exit -1
}

# helper function to slurp in all of the text in filename and return as string
function slurp_cmd(cmd,    text) {
	# if file is empty, just return now
	if ((cmd | getline) <= 0) {
		close(cmd)
		return ""
	}
	# otherwise, parse
	text = $0
	while ((cmd | getline) > 0)
		text = text "\n" $0
	close(cmd)
	return text
}


function slurp(filename,    text) {
	# if file is empty, just return now
	if ((getline < filename) <= 0) {
		close(filename)
		return ""
	}
	# otherwise, parse
	text = $0
	while ((getline < filename) > 0)
		text = text "\n" $0
	close(filename)
	return text
}
# need to escape < > & " ' in our source code
function html_escape(string) {
	gsub(/</, "\\&lt;", string)
	gsub(/>/, "\\&gt;", string)
	gsub(/"/, "\\&quot;", string)
	gsub(/'/, "\\&#39;", string)
	gsub(/&/, "\\&amp;", string)
	return string
}

function add_curdir(filename) {
	if (filename ~ "^\\.\\/") {
		return filename
	} else {
		return "./" filename
	}
}

# chops off the content or build part of a filename
# rules is rules to use for contentDir and buildDir
# filename is filename str to parse
# return filename stripped of build or content dir, does
# not include a path character at beginning 
function get_basepath(rules, filename,    contentDir, buildDir) {
	contentDir = add_curdir(ini_str(rules,"contentDir"))
	buildDir = add_curdir(ini_str(rules,"buildDir"))
	filename = add_curdir(filename)

	# pull off the content or build section of the path
	if (index(filename, contentDir) == 1) {
		filename = substr(filename, length(contentDir)+1)
	} else if (index(filename, buildDir) == 1) {
		filename = substr(filename, length(buildDir)+1)
	}

	# if the stripped of filename still has a path char at the
	# beginning, strip that off
	if (index(filename,"/") == 1) {
		return substr(filename, 2)
	} else if (index(filename,"./") == 1) {
		return substr(filename, 3)
	} else {
		return filename
	}
}

function parse_iso8601(string, date,    orig_str, regex_str, key_str, regex_arr, key_arr, n, i) {
	# 	Year:
	#    YYYY (eg 1997)
	# Year and month:
	#    YYYY-MM (eg 1997-07)
	# Complete date:
	#    YYYY-MM-DD (eg 1997-07-16)
	# Complete date plus hours and minutes:
	#    YYYY-MM-DDThh:mmTZD (eg 1997-07-16T19:20+01:00)
	orig_str = string
	regex_str = "^ *|^[0-9]{4}|^-|^[0-9]{2}|^-|^[0-9]{2}|^T|^[0-9]{2}|^:|^[0-9]{2}"
	key_str = "x|Year|x|Month|x|Day|x|Hours|x|Minutes"

	n = split(regex_str, regex_arr, "|")
	if (split(key_str, key_arr, "|") != n) {
		die("bad regex in parse_iso8601")
	}

	for (i = 1; i <= n; i++){
		if (match(string,regex_arr[i])) {
			if (key_arr[i] != "x") {
				date[key_arr[i]] = substr(string, RSTART,RLENGTH)
			}
			string = substr(string, RSTART+RLENGTH)
		} else {
			break
		}
	}

	if (date["Day"] == "") {
		die(sprintf("puffin dates should at least include the day: %s", orig_str))
	}
}

function get_abmon_arr(abmon_arr,    tmp_arr, i) {
	cmd = "locale abmon"
	if ((cmd | getline) <= 0) {
		die("Error calling locale function")
	}
	close(cmd)
	split($0,tmp_arr, ";")
	for (i in tmp_arr) {
		abmon_arr[tmp_arr[i]] = i
	}
}

# populates date if necessary
function add_date(rules, filepath,     year, month, day, cmd, abmon_arr, field_arr) {
	if (! ("Date" in rules) || ini_str(rules,"Date") == "") {
		# need to use ls -l because this is the only POSIX way to get time modified
		cmd = "ls -l " filepath
		cmd | getline
		close(cmd)
		month = $6
		day = $7
		if ($8 ~ /:/) {
			cmd = "date +%Y"
			cmd | getline
			close(cmd)
			year = $0
		} else {
			year = $8
		}

		# convert month string to number
		get_abmon_arr(abmon_arr)
		ini_add_str(rules,"Date", sprintf("%d-%02d-%02d",year,abmon_arr[month],day))
	}

	parse_iso8601(ini_str(rules,"Date"),field_arr)
	rules["DateFields"] = ini_arr2frag(field_arr)
}

function add_pubdate(rules,   cmd) {
	if (! ("PubDate" in rules)) {
		cmd = "date +%Y-%m-%dT%T"
		if ((cmd | getline) <= 0) {
			die("Could not get current time")
		}
		close(cmd)
		ini_add_str(rules,"PubDate", $0)
	}
}

function add_autovars(rules, filepath,     n, fileparts, filename, ext, words, i, basepath, template_parts) {
	n = split(filepath, fileparts, "/")
	filename = fileparts[n]
	n = split(filename, fileparts, ".")
	ext = fileparts[n] # populate extension

	ini_add_str(rules,"filename", filepath)
	
	# populate title if not set
	if (! ("Title" in rules)) {
		n = split(fileparts[1], words, /[ \-_]/)
		for (i in words) {
			words[i] = toupper(substr(words[i], 1, 1)) substr(words[i], 2)
		}
		ini_add_str(rules,"Title", join(words, 1, n, " "))
	}

	# populate date
	add_date(rules, filepath)

	add_pubdate(rules)
	
	# populate permalink
	if (! ("Permalink" in rules)) {
		basepath = get_basepath(rules, filepath)
	n = split(basepath, fileparts, ".")
		ini_add_str(rules,"Permalink", "/" join(fileparts, 1, n-1, "."))
		if (ini_str(rules, "template") != "") {
			n = split(ini_str(rules, "template"), template_parts, ".")
			ini_add_str(rules,"Permalink", ini_str(rules,"Permalink") "." template_parts[n])
		} else {
			ini_add_str(rules,"Permalink", ini_str(rules,"Permalink") "." ext)
		}
	}
}

# copy all elements of array src to array dest
function acopy(dest, src,     i) {
	for (i in src)
		dest[i] = src[i]
}
