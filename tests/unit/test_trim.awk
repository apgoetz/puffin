END {
	assertEquals(trim("a"),"a")
	assertEquals(trim(" a"),"a")
	assertEquals(trim("a "),"a")
	assertEquals(trim(" a "),"a")
	assertEquals(trim("\ta"),"a")
	assertEquals(trim("a\t"),"a")
}
