# A High-Bandwidth Interleaved Data Memory System

Prathmesh Gabhane  
BITS ID: 2025H1400103P  
MEL G624 Advanced VLSI Architectures, Assignment 2

## 1. My understanding and assumptions

The specification leaves a few points open, so before writing the Verilog I set down here how I read the problem and the choices I made.

The system is a data memory for a vector processor. It must let the processor start one 32-bit word access (read or write) every clock cycle, even though a single memory bank needs 6 clock cycles to finish an access. The only way to hide a slow bank is to use several banks and spread the words across them, so that a run of accesses keeps moving from one bank to the next instead of waiting on one. There are eight banks. Each bank is word addressable, holds a 32-bit word per location, and takes a 10-bit address, so each bank has 1024 words and the whole memory has 8192 words, which is 32 KB. The processor gives a byte address; with 8192 words the word address is 13 bits and the byte address is 15 bits, and I take the bits above that to be zero.

The main choice is how words map to banks. I use low-order interleaving, which means consecutive words go to consecutive banks. The bank number is the lowest three bits of the word address and the row inside the bank is the rest:

```
word address = byte_addr[14:2]
bank number  = word address mod 8 = byte_addr[4:2]
row in bank  = word address / 8   = byte_addr[14:5]
```

This is the mapping that makes a unit-stride stream (word 0, 1, 2, and so on) visit banks 0, 1, 2, and so on in turn. A given bank is then used only once every eight cycles, which is longer than its six-cycle busy time, so it is always free again by the time the stream comes back to it. This is the whole idea of the design and it is what Test 1 shows.

The processor view is big-endian and byte addressable, but it always makes a four-byte word access aligned to a word boundary, so the two low byte-address bits are always zero. Because every access is a whole aligned word, the big-endian byte order inside a word is never actually exercised by the data path; it only means that byte address 4W holds the most significant byte of word W. My model therefore stores and returns whole 32-bit words and ignores the two low address bits.

For the timing of a bank, when a bank latches an access it becomes busy for six cycles and cannot take another access during that time. If the processor tries to use a busy bank the attempt is rejected and the stall signal goes high. I treat stall as an early warning: it is already low during the bank's last busy cycle, so an access that is held during that cycle is accepted on the edge at which the bank finishes its previous access. This matches the statement that stall is lowered during the clock cycle at the end of which the bank will complete its previous access and be ready to accept a new one. The memory system only rejects the access and raises stall; it does not store the rejected access, so I take it that the processor holds the same access and retries it every cycle until it is accepted. My testbench models this.

The results also come back in a simple way. Because the system accepts at most one access per cycle and every access takes the same fixed six cycles, the accesses finish in the same order they were started, so no reordering logic is needed; the system just reports each completion as it leaves its bank. A write commits to the bank's array when it completes, six cycles after it was accepted, and the write-complete signal is given at that time. The two required test cases are reads, but the model handles writes the same way.

Finally, to make the reads easy to check, each location is seeded so that a read of byte address A returns 0xC0DE0000 with (A divided by 4) in the low bits. So word 0 reads 0xC0DE0000, word 1 reads 0xC0DE0001, and so on, which lets the testbench check both the data and the order.

## 2. How the memory system works

The system has two kinds of block: eight identical banks, and a thin controller around them.

**The bank (mem_bank).** Each bank keeps a busy counter. When the controller tells it to take an access, it stores the address, the data and the type, and sets the counter to 6. The counter counts down one per cycle. When it reaches its last step the access completes: for a read the bank loads its 32-bit output register from the array, for a write it writes the array, and it pulses a done signal for one cycle. The bank also gives the controller a combinational "can accept" flag, which is true when the bank is free or is finishing on the coming edge (counter is 0 or 1).

**The controller (mem_system).** Each cycle it splits the byte address into a bank number and a row (as in Interpretation 1). It looks at the "can accept" flag of the selected bank:

- if the bank can accept, it enables that one bank, which latches the access on the next edge;
- if the bank cannot accept (it is busy), it raises stall and enables no bank, so the access is rejected.

When a bank finishes, the controller passes its done pulse and output register to the processor as read_complete and read_data (or write_complete for a write). Because only one bank finishes in any cycle, this is just a simple selection.

**Why 8 banks and 6 cycles.** For a unit-stride stream the controller sends access 0 to bank 0, access 1 to bank 1, and so on up to bank 7, then back to bank 0 for access 8. Access 8 reaches bank 0 eight cycles after access 0, but bank 0 only stays busy for 6 cycles, so it is already free. No access ever meets a busy bank, so there are no stalls and the system starts one access every cycle. In short, the design works at full speed as long as there are more banks than the bank access time, and the stride visits different banks.

## 3. Test setup

The testbench contains a small processor model. Every cycle it presents one read access. If stall is high it holds the same access and tries again next cycle; if stall is low the access is accepted and it moves to the next one. It records when each access is issued and checks each completed read against the expected value and the expected order.

Two test cases are run, as asked:

- Test 1: 16 reads to 16 successive words, byte addresses 0, 4, 8, ..., 60 (stride 4 bytes = one word).
- Test 2: 16 reads with a stride of 16 bytes, byte addresses 0, 16, 32, ..., 240 (stride 4 words).

## 4. Results

### Test 1 (unit stride)

Every access goes to a different bank in turn, so nothing ever stalls. The 16 reads are issued one per cycle and the results come back one per cycle, in order, after the 6-cycle fill.

```
cyc 1 : ISSUE  read #0  byte_addr=0x000  (bank 0, row 0)
cyc 2 : ISSUE  read #1  byte_addr=0x004  (bank 1, row 0)
cyc 3 : ISSUE  read #2  byte_addr=0x008  (bank 2, row 0)
cyc 4 : ISSUE  read #3  byte_addr=0x00c  (bank 3, row 0)
cyc 5 : ISSUE  read #4  byte_addr=0x010  (bank 4, row 0)
cyc 6 : ISSUE  read #5  byte_addr=0x014  (bank 5, row 0)
cyc 7 : ISSUE  read #6  byte_addr=0x018  (bank 6, row 0)
cyc 8 : ISSUE  read #7  byte_addr=0x01c  (bank 7, row 0)
cyc 8 : COMPLETE read #0 data=0xc0de0000  (ok)
cyc 9 : ISSUE  read #8  byte_addr=0x020  (bank 0, row 1)
cyc 9 : COMPLETE read #1 data=0xc0de0001  (ok)
...
cyc 16 : ISSUE  read #15 byte_addr=0x03c  (bank 7, row 1)
cyc 16 : COMPLETE read #8  data=0xc0de0008  (ok)
cyc 17 : COMPLETE read #9  data=0xc0de0009  (ok)
cyc 23 : COMPLETE read #15 data=0xc0de000f  (ok)
----------------------------------------------------
issued 16 reads over cycles 1..16  (16 cycles)
stalls (rejected attempts) : 0
sustained initiation rate  : 16/16 = 1.00 words/cycle
```

All 16 reads are accepted in 16 back-to-back cycles with no stalls, and every value is correct and in order. This is the full bandwidth the system is designed for: one word per cycle.

Figure 1 shows the simulation waveform for this run.

![Figure 1. Test 1 (unit stride). req is high every cycle and stall stays low; byte_addr steps through consecutive words and bank_sel cycles through all eight banks, so read_complete asserts once per cycle and read_data steps c0de0000, c0de0001, and so on. The system runs at one word per cycle.](results/wave_test1.png){width=6.5in}

### Test 2 (stride of 16 bytes)

A stride of 16 bytes is 4 words. The bank number is (word address mod 8), and the word addresses are 0, 4, 8, 12, 16, ..., so the banks used are 0, 4, 0, 4, 0, 4, ... Only two of the eight banks are ever used, and each is needed every second access. Since a bank is busy for 6 cycles, the stream cannot keep up and stalls badly.

```
cyc 1 : ISSUE  read #0  byte_addr=0x000  (bank 0, row 0)
cyc 2 : ISSUE  read #1  byte_addr=0x010  (bank 4, row 0)
cyc 3 : STALL  retry byte_addr=0x020  (bank 0 busy)
cyc 4 : STALL  retry byte_addr=0x020  (bank 0 busy)
cyc 5 : STALL  retry byte_addr=0x020  (bank 0 busy)
cyc 6 : STALL  retry byte_addr=0x020  (bank 0 busy)
cyc 7 : ISSUE  read #2  byte_addr=0x020  (bank 0, row 1)
cyc 8 : ISSUE  read #3  byte_addr=0x030  (bank 4, row 1)
cyc 8 : COMPLETE read #0 data=0xc0de0000  (ok)
cyc 9 : COMPLETE read #1 data=0xc0de0004  (ok)
... (the pattern repeats: two reads issued, then four stall cycles) ...
cyc 43 : ISSUE  read #14 byte_addr=0x0e0  (bank 0, row 7)
cyc 44 : ISSUE  read #15 byte_addr=0x0f0  (bank 4, row 7)
cyc 50 : COMPLETE read #14 data=0xc0de0038  (ok)
cyc 51 : COMPLETE read #15 data=0xc0de003c  (ok)
----------------------------------------------------
issued 16 reads over cycles 1..44  (44 cycles)
stalls (rejected attempts) : 28
sustained initiation rate  : 16/44 = 0.36 words/cycle
```

After the first pair, the system settles into a steady pattern of two reads issued, then four stall cycles, i.e. two accesses every six cycles. That is 2/6 = 0.33 words per cycle in steady state; over the whole run it averages 16/44 = 0.36 words per cycle. The data is still correct and in order; only the speed drops.

Figure 2 shows the simulation waveform for this run.

![Figure 2. Test 2 (16-byte stride). bank_sel only ever takes the values 0 and 4, so the same two banks are reused; stall is high for four of every six cycles while a busy bank is waited on. The reads still complete in order (read_data c0de0000, c0de0004, ...) but far more slowly.](results/wave_test2.png){width=6.5in}

### Comparison

| | Test 1 (stride 4B) | Test 2 (stride 16B) |
|---|---|---|
| Banks used | all 8 | only bank 0 and bank 4 |
| Stall cycles | 0 | 28 |
| Cycles to issue 16 reads | 16 | 44 |
| Sustained rate | 1.00 word/cycle | 0.36 word/cycle |

The two runs make the point of the design clear. Interleaving gives the full rate only when consecutive accesses land on different banks. When the stride is a multiple of a factor of the bank count (here 16 bytes = 4 words, and 4 shares the factor 4 with 8), the stream folds onto a few banks and the 6-cycle bank time shows through as stalls. The same memory therefore delivers about three times the bandwidth on Test 1 as on Test 2 purely because of how the addresses map to banks.

## 5. Conclusion

The memory system meets the goal: with eight banks and low-order interleaving it starts one 32-bit word access per cycle for a unit-stride stream, even though each bank needs 6 cycles per access, because 8 banks is more than the 6-cycle bank time. A busy bank is handled by rejecting the access and raising stall, and the processor holds and retries. Results come out in the order the accesses were made without any extra ordering logic, because every access has the same latency and at most one is accepted per cycle. The simulation confirms correct data and correct order in both test cases, and shows the expected drop from 1.00 to 0.36 words per cycle when a bad stride collapses the stream onto two banks.

The well-commented Verilog for the bank, the memory system and the testbench processor model follows in the appendix.
