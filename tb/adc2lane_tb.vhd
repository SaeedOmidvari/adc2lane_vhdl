library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_adc2lane is
end entity;

architecture sim of tb_adc2lane is
  constant USPI_SIZE : integer := 16;

  signal resetn   : std_logic := '0';
  signal bclk     : std_logic := '0';
  signal spi_clkp : std_logic := '0';
  signal start    : std_logic := '0';
  signal done     : std_logic;
  signal scsq     : std_logic;
  signal sclk     : std_logic;
  signal sdi_0    : std_logic := '0';
  signal sdi_1    : std_logic := '0';
  signal rcv0     : std_logic_vector(USPI_SIZE-1 downto 0);
  signal rcv1     : std_logic_vector(USPI_SIZE-1 downto 0);

  -- Example frames (16 bits). For AD7476A you'll later extract 12 bits.
  constant FRAME0 : std_logic_vector(15 downto 0) := x"A5C3";
  constant FRAME1 : std_logic_vector(15 downto 0) := x"3F0D";

  signal bit_idx : integer range 0 to 15 := 15;

begin
  -- DUT
  uut: entity work.adc2lane
    generic map (USPI_SIZE => USPI_SIZE)
    port map (
      resetn    => resetn,
      bclk      => bclk,
      spi_clkp  => spi_clkp,
      start     => start,
      done      => done,
      scsq      => scsq,
      sclk      => sclk,
      sdi_0     => sdi_0,
      sdi_1     => sdi_1,
      rcvData_0 => rcv0,
      rcvData_1 => rcv1
    );

  -- bclk = 100 MHz (10 ns period)
  bclk <= not bclk after 5 ns;

  -- spi_clkp: 1-cycle enable every 4 bclk cycles (adjust as you like)
  process
  begin
    spi_clkp <= '0';
    wait for 40 ns;
    spi_clkp <= '1';
    wait for 10 ns;
  end process;

  -- reset + start stimulus
  process
  begin
    resetn <= '0';
    wait for 100 ns;
    resetn <= '1';

    wait for 100 ns;
    start <= '1';
    wait for 20 ns;
    start <= '0';

    -- wait long enough for transfer
    wait for 5 us;

    -- check results
    assert rcv0 = FRAME0
      report "Mismatch: rcv0 != FRAME0" severity error;
    assert rcv1 = FRAME1
      report "Mismatch: rcv1 != FRAME1" severity error;

    report "Simulation PASSED" severity note;
    wait;
  end process;

  -- Simple "ADC model": shift out bits while CS is low.
  -- Because your DUT samples when transitioning to sclk_lo (CPHA=1 style),
  -- the easiest is to update SDI on SCLK rising edge (data stable for falling).
  process(sclk, scsq)
  begin
    if scsq = '1' then
      bit_idx <= 15;
      sdi_0 <= FRAME0(15);
      sdi_1 <= FRAME1(15);
    elsif rising_edge(sclk) then
      sdi_0 <= FRAME0(bit_idx);
      sdi_1 <= FRAME1(bit_idx);
      if bit_idx > 0 then
        bit_idx <= bit_idx - 1;
      end if;
    end if;
  end process;

end architecture;
