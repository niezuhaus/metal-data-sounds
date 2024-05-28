class ToneInstrument implements Instrument
{
  // create all variables that must be used througout the class
  Oscil osc;
  ADSR  adsr;

  // constructor for this instrument
  ToneInstrument(float freq, float amp)
  {
    // create new instances of any UGen objects as necessary
    osc = new Oscil(freq, amp, Waves.TRIANGLE);
    adsr = new ADSR(0.5, 0.01, 0.05, 0.5, 0.5);

    osc.patch(adsr);
  }

  void noteOn(float dur)
  {
    adsr.noteOn();
    adsr.patch(out);
  }

  void noteOff()
  {
    adsr.unpatchAfterRelease(out);
    adsr.noteOff();
  }
}

class ADSRInstrument extends ToneInstrument{
  ADSRInstrument(float freq, float amp, float a, float d, float s, float r) {
    super(freq, amp);
    adsr = new ADSR(1.0, a,d,s,r);
    osc.patch(adsr);
  }
}
