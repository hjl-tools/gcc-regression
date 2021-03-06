# Scripts to checkout GCC source, build GCC and run GCC testsuite

This package can be used to

1. Checkout GCC source.
2. Build GCC.
3. Run GCC testsuite.

The main script is "gcc-build", which assumes there is a GCC trunk
git tree named "src-trunk", which should be cloned by

$ git clone GCC-GIT-URL src-trunk

"gcc-build" takes options:

1. --with-cpu=CPU, passed to GCC configure script.
2. --with-arch=ARCH, passed to GCC configure script.
3. -m32, build for Linux/ia32 target.

You can set up cron jobs to automatically

1. Check if there are any GCC source changes.
2. Build and run GCC testsuite if there are relevant GCC source
changes.

Sample cron jobs are

1. Check and build Linux/x86-64 GCC with 2 configure options.

---
PATH=/usr/local/bin:/bin:/usr/bin
# Build gcc every 15 minutes from 9pm to 5am
10,25,40,55 0-5,21-23 * * * /export/gnu/import/git/gcc-test-intel64corei7/gcc-build --with-arch=corei7 --with-cpu=intel > /dev/null 2>&1
# Build gcc every 15 minutes from 6am to 8pm
10,25,40,55 6-20 * * * /export/gnu/import/git/gcc-test-intel64corei7/gcc-build --with-arch=corei7 --with-cpu=corei7 > /dev/null 2>&1
---

2. Check and build Linux/ia32 GCC with 2 configure options.

---
PATH=/usr/local32/bin:/bin:/usr/bin
# Build gcc every 15 minutes from 9pm to 5am
10,25,40,55 0-5,21-23 * * * /export/gnu/import/git/gcc-test-ia32corei7/gcc-build --with-arch=corei7 --with-cpu=intel -m32 > /dev/null 2>&1
# Build gcc every 15 minutes from 6am to 8pm
10,25,40,55 6-20 * * * /export/gnu/import/git/gcc-test-ia32corei7/gcc-build --with-arch=corei7 --with-cpu=corei7 -m32 > /dev/null 2>&1
---

You must install Linux/ia32 binutils under /usr/local32/bin.  Otherwise,
GCC testsuite run will have many failures since linker will dlopen GCC
plugin which is a Linux/ia32 shared library.

You need to create a mail configure file, mail.conf, which contains

1. MAILTO, email recipient recipient when something goes wrong.
2. REGRESSION-MAILTO, additional email recipient when there is any GCC
regression.
