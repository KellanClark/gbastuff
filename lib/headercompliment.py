file = open("main.gba", "rb")
headerData = list(file.read(0xC0))
file.close()

complement = 0
for i in range(0xA0, 0xBD):
	complement = complement - headerData[i]

complement = (complement - 0x19) & 0xFF
print(hex(complement))