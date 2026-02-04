echo 0 sys5632|petcat -w2 -l 0x1001 > demo-synth.prg
truncate -s 1537 demo-synth.prg
xa -o- -DMAPLIN -Isrc -l demo-synth.lbl src/demo-synth.asm >> demo-synth.prg
sed -i s/0x/\$/g demo-synth.lbl; cut -d, -f1-2 --output-delimiter=\ = demo-synth.lbl|tee demo-synth.lbl > /dev/null
