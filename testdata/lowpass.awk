
BEGIN {
x3 = 0;
x2 = 0;
x1 = 0;
}

{
  print $1 "\t" (x3+x2+x1)/3;
  x3 = x2;
  x2 = x1;
  x1 = $2;
}
