#!/usr/bin/python3
################################################################################
# new_subs.py
# By: Ammar Ratnani
#
# This program serves as a subroutine to gtr_anime.sh. It will take in the old 
# srt file and the new subtitles (one per line) as parameters, and will write 
# the new srt file to stdout.
################################################################################


import sys

# Returns a string with no lines passing n characters
def limit_char(st, n):
	ret = ""
	count = 0
	for ss in st.split(" "):
		if count + len(ss) + 1 > n:
			ret += "\n"
			count = 0
		ret += ss + " "
		count += len(ss) + 1
	return ret

# Open old and new subtitles
with open(sys.argv[1], "r") as old_sub, open(sys.argv[2], "r") as new_sub:
	state = 0 # 0 for before subs, 1 in subs, 2 after subs
	for line in old_sub:
		line = line.strip()
		if state == 0:
			print(line)
			if " --> " in line:
				state = 1
		elif state == 1:
			new = new_sub.readline().strip()
			if new == "null":
				print("[Uninteligible]")
			else:
				print(limit_char(new, 50))
			state = 2
		elif state == 2:
			if line == "":
				print()
				state = 0
	old_sub.close()
	new_sub.close()