"""
Not essential but explains a bit better how binary operations can work
As solidity doesn't make it super easy to view binary values.

Just run this with scripts/binary.py to look at the logs, we replicate this kind
of logic in the MerkleDistributor and in the RollStaker
"""

size = 32                                                       # in solidity we use 256bits, but 32 makes for nicer logs
empty_slot = 0

# print decimal in binary in little endian with leading zeros
def bprint(input: int, desc: str = ""):
    return print(format(input, f"#0{size + 2}b"), f"       {desc}")

# bitmask is just all binary values flipped to "on" up to a certain point
def bitmask(len: int):
    return (1 << len) - 1

 # Initialize a full storage slot.
 # You can't do this using the same function logic with uint8 in solidity
 # because the max value of an 8 bit integer is 255.
full_slot = bitmask(size)

def deactivateFrom(bitfield, _epochFrom):
    return bitfield & bitmask(_epochFrom);


def activateFrom(bitfield, _epochFrom):
    activator = full_slot ^ bitmask(_epochFrom);
    return bitfield | activator;


bprint(empty_slot, "EMPTY ARRAY")
bprint(full_slot, "FULL ARRAY")

print()

start_epoch = 5                                                     # user starts at epoch 5
offset = bitmask(start_epoch)                                       # bitmask for first 5 epochs
bprint(offset, f"FIRST {start_epoch} OFFSET")

claims = offset ^ full_slot                                         # xor with the bitmask yields 0 for the first 5 bits
bprint(claims, f"IGNORING FIRST {start_epoch} CLAIMS")              # all epochs set to 1 from epoch 5 onwards

ac_from = activateFrom(empty_slot, start_epoch)                     # this should yield the same result as above
bprint(ac_from, f"== ACTIVATE FROM EPOCH {start_epoch}")

print()

epoch_offline = 10                                                  # user leaves at epoch 10
mask = bitmask(epoch_offline)                                       # next bitmask at epoch 10 will prevent overwriting existing data (1st 10 epochs)
claims = (mask & claims)                                            # bitwise AND will put all subsequent claims past epoch 10 back to zero
bprint(claims, f"OFFLINE FROM EPOCH {epoch_offline}")

de_from = deactivateFrom(ac_from, epoch_offline)                    # this should yield the same result as above
bprint(de_from, f"== DEACTIVATE FROM FROM EPOCH {epoch_offline}")

repeat_deactive = deactivateFrom(de_from, epoch_offline)            # repeated deactivation should not change anything
bprint(repeat_deactive, f"REPEAT DEACTIVATE EPOCH {epoch_offline}")

print()

epoch_back = 15                                                     # user comes back at epoch 15
bitmask_turn_on = bitmask(epoch_back)                               # this bitmask will prevent overwriting data before epoch 15
resume = bitmask_turn_on ^ full_slot                                # creates 1's for all bits 15th and above
bprint(resume, "RESUME XOR")

claims = resume | claims
bprint(claims, "RESUME FROM EPOCH 15")                              # or with the bitmask to return the original data for 1st 15 bits

ac_resume = activateFrom(de_from, epoch_back)                       # this should yield the same result as above
bprint(ac_resume, f"== ACTIVATE AGAIN EPOCH {epoch_back}")

repeat_active = activateFrom(ac_resume, epoch_back)                 # repeated activation should not change anything
bprint(repeat_active, f"REPEAT ACTIVATE EPOCH {epoch_back}")

print()

epoch_overwrite = 7                                                 # overrite data from past epoch

ac_over = activateFrom(ac_resume, epoch_overwrite)
bprint(ac_over, f"OVERWRITE EPOCH ACTIVE {epoch_overwrite}")        # should replace all data from overwrite as active

de_over = deactivateFrom(ac_resume, epoch_overwrite)
bprint(de_over, f"OVERWRITE EPOCH DEACTIVE {epoch_overwrite}")      # should replace all data from overwrite as inactive
