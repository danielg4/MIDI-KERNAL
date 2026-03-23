echo 0 sys5632|petcat -w2 -l 0x1001 > demo-synth-pal.prg &&
truncate -s 1537 demo-synth-pal.prg &&
cp demo-synth-pal.prg demo-synth-ntsc.prg &&
#cp demo-synth-pal.prg demo-synth-prio-ntsc.prg &&
#cp demo-synth-pal.prg demo-synth-prio-pal.prg &&
#xa -o- -DPER_CHANNEL_NOTE_OFF -DLOW_NOTE_PRIORITY -DMAPLIN -Isrc -l demo-synth-prio.lbl src/demo-synth.asm >> demo-synth-prio-ntsc.prg &&
#xa -o- -DPER_CHANNEL_NOTE_OFF -DLOW_NOTE_PRIORITY -DMAPLIN -DPAL -Isrc src/demo-synth.asm >> demo-synth-prio-pal.prg &&
xa -o- -DMAPLIN -Isrc -l demo-synth.lbl src/demo-synth.asm >> demo-synth-ntsc.prg &&
xa -o- -DMAPLIN -DPAL -Isrc src/demo-synth.asm >> demo-synth-pal.prg &&
#sed -i s/0x/\$/g demo-synth-prio.lbl && cut -d, -f1-2 --output-delimiter=\ = demo-synth-prio.lbl|tee demo-synth-prio.lbl > /dev/null &&
sed -i s/0x/\$/g demo-synth.lbl && cut -d, -f1-2 --output-delimiter=\ = demo-synth.lbl|tee demo-synth.lbl > /dev/null
