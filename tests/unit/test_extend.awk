# test the extend function

END {
	# test we can extend
	arr1[1] = "foo"
	arr2[1] = "bar"
	retval = extend(arr1,1,arr2,1)
	assertEquals(retval, 2)
	assertEquals(arr1[2], "bar")
}
