library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;

-- timing diagram:
--   clk ||   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |
--    ph ||   1   |   2   |   3   |   0   |   1   |   2   |   3   |   0   |
--  trIn || t1,t0 |       | t3,t2 |       | t1,t0 |       | t3,t2 |       |
-- trOut ||                       | t2,t0 |       | t3,t1 |       | t2,t0 |
entity fft4_serial5_natural_transposer is
	generic(dataBits: integer := 18);
	port(clk: in std_logic;
		din: in complexArray(1 downto 0);
		phase: in unsigned(1 downto 0);
		doutA, doutB: out complexArray(1 downto 0));
end entity;

architecture ar of fft4_serial5_natural_transposer is
	signal ph1: unsigned(1 downto 0);
	signal registers: complexArray(3 downto 0);
	signal reg1_1: complex;
begin
	registers(0) <= din(0) when phase=1 and rising_edge(clk);
	registers(1) <= din(1) when phase=1 and rising_edge(clk);
	registers(2) <= din(0) when phase=3 and rising_edge(clk);
	registers(3) <= din(1) when phase=3 and rising_edge(clk);
	
	reg1_1 <= registers(1) when rising_edge(clk);
	
	doutA <= (registers(2), registers(0));
	doutB <= (complex_swap(registers(3)), reg1_1);
end ar;

library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.fft4_serial4_bf;
use work.fft4_serial5_natural_transposer;

-- total delay is 11 cycles
-- data input is in natural order and output is in bit reversed order
entity fft4_serial5_natural is
	generic(dataBits: integer := 18;
			scale: scalingModes := SCALE_NONE;
			round: boolean := true);

	port(clk: in std_logic;
		din: in complex;
		phase: in unsigned(1 downto 0);
		dout: out complex
		);
end entity;
architecture ar of fft4_serial5_natural is
	constant shift: integer := scalingShift(scale, 2);
	signal ph, ph1: unsigned(1 downto 0);
	--signal srIn: complexArray(3 downto 0);
	signal iReg, iReg2, iReg3: complex;
	signal bfIn, bfOutP, trIn: complexArray(1 downto 0);
	signal bfRound: std_logic;
	
	signal trOutA, trOutB: complexArray(1 downto 0);
	signal bfOut0del, dout0: complex;
begin

--   clk ||   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |   -   |
--    ph ||   0   |   1   |   2   |   3   |   0   |   1   |   2   |   3   |   0   |   1   |   2   |   3   |   0   |   1   |
--  srIn || 3210  | 0321  | 1032  | 2103  | 3210  | 0321  | 1032  | 2103  | 3210  | 0321  | 1032  | 2103  |
--  iReg ||       |       0       |   2   |   3   |       0       |
-- iReg2 ||                       |   0   |       |   3   |
-- iReg3 ||               |               1               |
--  bfIn ||                       | i2,i0 |       | i3,i1 |       | i2,i0 | t2,t0 | i3,i1 | t3,t1 |
--bfOutP ||                                       | t1,t0 |       | t3,t2 |       | t1,t0 | o2,o0 | t3,t2 | o3,o1 |
-- trOut ||                                                               | t2,t0 |       | t3,t1 |

	ph <= phase+1 when rising_edge(clk);
	ph1 <= phase when rising_edge(clk);
	--srIn <= din & srIn(3 downto 1) when rising_edge(clk);
	
	iReg <= din when (ph /= 1) and rising_edge(clk);
	iReg2 <= iReg when rising_edge(clk);
	iReg3 <= din when (ph = 1) and rising_edge(clk);
	
	bfIn <= (iReg, iReg2) when ph=3 else
			(to_complex(iReg2.re, iReg3.im), to_complex(iReg3.re, iReg2.im)) when ph=1 else
			trOutA when ph=0 else
			trOutB;
	bfRound <= '1' when ph=0 or ph=2 else
				'0';
	trIn <= bfOutP;
	
	bf: entity fft4_serial4_bf
		generic map(dataBits=>dataBits+2, carryPosition=>shift-1)
		port map(clk=>clk, din=>bfIn, roundIn=>bfRound, dout=>bfOutP);
	
	tr: entity fft4_serial5_natural_transposer
		generic map(dataBits=>dataBits+1)
		port map(clk=>clk, din=>trIn, phase=>ph,
				doutA=>trOutA, doutB=>trOutB);
	
	bfOut0del <= bfOutP(1) when rising_edge(clk);
	dout0 <= bfOutP(0) when ph=2 else
			bfOut0del when ph=3 else
			bfOutP(0) when ph=0 else
			bfOut0del;
	
	dout <= keepNBits(shift_right(dout0, shift), dataBits) when rising_edge(clk);
end ar;
