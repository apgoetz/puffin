END {
	assertTrue(is_empty(foo))
	foo[1]="asdf"
	assertFalse(is_empty(foo))
}
