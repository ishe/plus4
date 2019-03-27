#- Bin2Hex.pl
#- Copyright (c) 1995 by Dr. Herong Yang, http://www.herongyang.com/
#
   ($in, $out) = @ARGV;
   die "Missing input file name.\n" unless $in;
   die "Missing output file name.\n" unless $out;
   $byteCount = 0;
   open(IN, "< $in");
   binmode(IN);
   open(OUT, "> $out");
   while (read(IN,$b,1)) {
      $n = length($b);
      $byteCount += $n;
      $s = 2*$n;
      print (OUT unpack("H$s", $b), "\n");
   }
   close(IN);
   close(OUT);
   print "Number of bytes converted = $byteCount\n";
   exit;
