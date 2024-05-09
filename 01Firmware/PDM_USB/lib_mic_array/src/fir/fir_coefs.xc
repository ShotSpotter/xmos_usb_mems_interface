// Copyright (c) 2024, XMOS Ltd, All rights reserved
const int g_first_stage_fir_0[256] = {
	0xfdc3b1f7, 0xff3acfac, 0xfed512c8, 0x004c307d, 0xfe83e9ec, 0xfffb07a1, 0xff954abd, 0x010c6872, 
	0xfe4539da, 0xffbc5790, 0xff569aac, 0x00cdb860, 0xff0571cf, 0x007c8f84, 0x0016d2a0, 0x018df055, 
	0xfe1689d0, 0xff8da786, 0xff27eaa2, 0x009f0857, 0xfed6c1c5, 0x004ddf7a, 0xffe82297, 0x015f404c, 
	0xfe9811b4, 0x000f2f68, 0xffa97285, 0x0120903a, 0xff5849a9, 0x00cf675d, 0x0069aa79, 0x01e0c82f, 
	0xfdf538d1, 0xff6c5687, 0xff0699a3, 0x007db758, 0xfeb570c6, 0x002c8e7b, 0xffc6d198, 0x013def4d, 
	0xfe76c0b4, 0xffedde6a, 0xff882186, 0x00ff3f3b, 0xff36f8a9, 0x00ae165e, 0x0048597a, 0x01bf7730, 
	0xfe4810ab, 0xffbf2e61, 0xff59717d, 0x00d08f31, 0xff0848a0, 0x007f6655, 0x0019a971, 0x0190c726, 
	0xfec9988e, 0x0040b643, 0xffdaf960, 0x01521715, 0xff89d083, 0x0100ee38, 0x009b3154, 0x02124f0a, 
	0xfddea5a6, 0xff55c35b, 0xfef00677, 0x0067242c, 0xfe9edd9b, 0x0015fb4f, 0xffb03e6c, 0x01275c21, 
	0xfe602d89, 0xffd74b3f, 0xff718e5b, 0x00e8ac0f, 0xff20657e, 0x00978333, 0x0031c64e, 0x01a8e404, 
	0xfe317d7f, 0xffa89b35, 0xff42de51, 0x00b9fc06, 0xfef1b574, 0x0068d329, 0x00031645, 0x017a33fb, 
	0xfeb30562, 0x002a2317, 0xffc46634, 0x013b83e9, 0xff733d57, 0x00ea5b0c, 0x00849e28, 0x01fbbbde, 
	0xfe102c80, 0xff874a36, 0xff218d52, 0x0098ab07, 0xfed06475, 0x0047822a, 0xffe1c547, 0x0158e2fc, 
	0xfe91b463, 0x0008d218, 0xffa31535, 0x011a32ea, 0xff51ec58, 0x00c90a0d, 0x00634d29, 0x01da6adf, 
	0xfe63045a, 0xffda2210, 0xff74652b, 0x00eb82e0, 0xff233c4f, 0x009a5a04, 0x00349d1f, 0x01abbad5, 
	0xfee48c3d, 0x005ba9f2, 0xfff5ed0f, 0x016d0ac4, 0xffa4c432, 0x011be1e7, 0x00b62503, 0x022d42b9, 
	0xfdd2bd47, 0xff49dafd, 0xfee41e19, 0x005b3bce, 0xfe92f53c, 0x000a12f1, 0xffa4560e, 0x011b73c3, 
	0xfe54452b, 0xffcb62e1, 0xff65a5fc, 0x00dcc3b1, 0xff147d20, 0x008b9ad5, 0x0025ddf0, 0x019cfba6, 
	0xfe259521, 0xff9cb2d7, 0xff36f5f3, 0x00ae13a8, 0xfee5cd16, 0x005ceacb, 0xfff72de8, 0x016e4b9d, 
	0xfea71d04, 0x001e3ab9, 0xffb87dd6, 0x012f9b8b, 0xff6754f9, 0x00de72ae, 0x0078b5ca, 0x01efd380, 
	0xfe044422, 0xff7b61d8, 0xff15a4f4, 0x008cc2a9, 0xfec47c17, 0x003b99cc, 0xffd5dce9, 0x014cfa9e, 
	0xfe85cc05, 0xfffce9bb, 0xff972cd7, 0x010e4a8c, 0xff4603fa, 0x00bd21af, 0x005764cb, 0x01ce8281, 
	0xfe571bfc, 0xffce39b2, 0xff687ccd, 0x00df9a82, 0xff1753f1, 0x008e71a5, 0x0028b4c1, 0x019fd277, 
	0xfed8a3df, 0x004fc194, 0xffea04b1, 0x01612265, 0xff98dbd4, 0x010ff989, 0x00aa3ca5, 0x02215a5a, 
	0xfdedb0f6, 0xff64ceac, 0xfeff11c8, 0x00762f7d, 0xfeade8eb, 0x002506a0, 0xffbf49bd, 0x01366772, 
	0xfe6f38da, 0xffe6568f, 0xff8099ab, 0x00f7b760, 0xff2f70cf, 0x00a68e83, 0x0040d19f, 0x01b7ef55, 
	0xfe4088d0, 0xffb7a686, 0xff51e9a2, 0x00c90757, 0xff00c0c5, 0x0077de7a, 0x00122196, 0x01893f4c, 
	0xfec210b3, 0x00392e68, 0xffd37185, 0x014a8f3a, 0xff8248a8, 0x00f9665d, 0x0093a979, 0x020ac72f, 
	0xfe1f37d1, 0xff965587, 0xff3098a3, 0x00a7b657, 0xfedf6fc6, 0x00568d7b, 0xfff0d098, 0x0167ee4c, 
	0xfea0bfb4, 0x0017dd69, 0xffb22086, 0x01293e3b, 0xff60f7a9, 0x00d8155e, 0x0072587a, 0x01e97630, 
	0xfe720fab, 0xffe92d60, 0xff83707c, 0x00fa8e31, 0xff3247a0, 0x00a96554, 0x0043a870, 0x01bac626, 
	0xfef3978e, 0x006ab543, 0x0004f85f, 0x017c1614, 0xffb3cf83, 0x012aed38, 0x00c53054, 0x023c4e09, 
	};

const int g_first_stage_fir_1[256] = {
	0xedfe4704, 0xf57d1c11, 0xf48bd976, 0xfc0aae83, 0xf39fa6c2, 0xfb1e7bce, 0xfa2d3934, 0x01ac0e3f, 
	0xf2be3933, 0xfa3d0e3f, 0xf94bcba5, 0x00caa0b0, 0xf85f98f0, 0xffde6dfd, 0xfeed2b62, 0x066c006e, 
	0xf1ec454b, 0xf96b1a57, 0xf879d7bc, 0xfff8acc9, 0xf78da508, 0xff0c7a15, 0xfe1b377a, 0x059a0c85, 
	0xf6ac3779, 0xfe2b0c86, 0xfd39c9eb, 0x04b89ef6, 0xfc4d9737, 0x03cc6c42, 0x02db29a8, 0x0a59feb4, 
	0xf12d6035, 0xf8ac3541, 0xf7baf2a6, 0xff39c7b3, 0xf6cebff2, 0xfe4d94ff, 0xfd5c5264, 0x04db276f, 
	0xf5ed5263, 0xfd6c2770, 0xfc7ae4d5, 0x03f9b9e0, 0xfb8eb221, 0x030d872c, 0x021c4492, 0x099b199e, 
	0xf51b5e7b, 0xfc9a3387, 0xfba8f0ed, 0x0327c5f8, 0xfabcbe39, 0x023b9344, 0x014a50a9, 0x08c925b6, 
	0xf9db50a9, 0x015a25b5, 0x0068e31a, 0x07e7b827, 0xff7cb067, 0x06fb8573, 0x060a42d8, 0x0d8917e4, 
	0xf083f2fb, 0xf802c808, 0xf711856d, 0xfe905a7a, 0xf62552b9, 0xfda427c5, 0xfcb2e52b, 0x0431ba36, 
	0xf543e52a, 0xfcc2ba36, 0xfbd1779c, 0x03504ca7, 0xfae544e7, 0x026419f3, 0x0172d758, 0x08f1ac65, 
	0xf471f142, 0xfbf0c64e, 0xfaff83b3, 0x027e58bf, 0xfa1350ff, 0x0192260b, 0x00a0e370, 0x081fb87c, 
	0xf931e370, 0x00b0b87c, 0xffbf75e2, 0x073e4aed, 0xfed3432e, 0x06521839, 0x0560d59f, 0x0cdfaaab, 
	0xf3b30c2c, 0xfb31e138, 0xfa409e9d, 0x01bf73a9, 0xf9546be9, 0x00d340f5, 0xffe1fe5b, 0x0760d367, 
	0xf872fe5a, 0xfff1d367, 0xff0090cc, 0x067f65d7, 0xfe145e18, 0x05933323, 0x04a1f089, 0x0c20c595, 
	0xf7a10a72, 0xff1fdf7e, 0xfe2e9ce4, 0x05ad71ef, 0xfd426a30, 0x04c13f3b, 0x03cffca0, 0x0b4ed1ad, 
	0xfc60fca0, 0x03dfd1ac, 0x02ee8f11, 0x0a6d641e, 0x02025c5d, 0x0981316a, 0x088feecf, 0x100ec3db, 
	0xeff13c25, 0xf7701131, 0xf67ece96, 0xfdfda3a3, 0xf5929be2, 0xfd1170ef, 0xfc202e54, 0x039f0360, 
	0xf4b12e53, 0xfc300360, 0xfb3ec0c5, 0x02bd95d0, 0xfa528e11, 0x01d1631c, 0x00e02082, 0x085ef58e, 
	0xf3df3a6b, 0xfb5e0f77, 0xfa6cccdd, 0x01eba1e8, 0xf9809a29, 0x00ff6f34, 0x000e2c99, 0x078d01a6, 
	0xf89f2c99, 0x001e01a5, 0xff2cbf0b, 0x06ab9417, 0xfe408c57, 0x05bf6163, 0x04ce1ec8, 0x0c4cf3d4, 
	0xf3205555, 0xfa9f2a61, 0xf9ade7c7, 0x012cbcd2, 0xf8c1b513, 0x00408a1e, 0xff4f4784, 0x06ce1c90, 
	0xf7e04784, 0xff5f1c90, 0xfe6dd9f5, 0x05ecaf01, 0xfd81a741, 0x05007c4d, 0x040f39b2, 0x0b8e0ebe, 
	0xf70e539b, 0xfe8d28a8, 0xfd9be60d, 0x051abb19, 0xfcafb359, 0x042e8864, 0x033d45ca, 0x0abc1ad6, 
	0xfbce45ca, 0x034d1ad5, 0x025bd83b, 0x09daad47, 0x016fa586, 0x08ee7a93, 0x07fd37f8, 0x0f7c0d05, 
	0xf276e81c, 0xf9f5bd28, 0xf9047a8d, 0x00834f99, 0xf81847d9, 0xff971ce6, 0xfea5da4b, 0x0624af57, 
	0xf736da4a, 0xfeb5af57, 0xfdc46cbc, 0x054341c7, 0xfcd83a08, 0x04570f13, 0x0365cc79, 0x0ae4a185, 
	0xf664e662, 0xfde3bb6e, 0xfcf278d4, 0x04714ddf, 0xfc064620, 0x03851b2b, 0x0293d890, 0x0a12ad9d, 
	0xfb24d891, 0x02a3ad9c, 0x01b26b01, 0x0931400e, 0x00c6384d, 0x08450d5a, 0x0753cabf, 0x0ed29fcb, 
	0xf5a6014c, 0xfd24d658, 0xfc3393be, 0x03b268c9, 0xfb47610a, 0x02c63615, 0x01d4f37a, 0x0953c887, 
	0xfa65f37b, 0x01e4c886, 0x00f385eb, 0x08725af8, 0x00075337, 0x07862844, 0x0694e5a9, 0x0e13bab5, 
	0xf993ff92, 0x0112d49e, 0x00219203, 0x07a06710, 0xff355f50, 0x06b4345b, 0x05c2f1c1, 0x0d41c6cd, 
	0xfe53f1c1, 0x05d2c6cc, 0x04e18432, 0x0c60593e, 0x03f5517d, 0x0b74268a, 0x0a82e3ef, 0x1201b8fc, 
	};

const int g_first_stage_fir_2[256] = {
	0xd43e0707, 0xe0d489a8, 0xe0a7ac99, 0xed3e2f3a, 0xe04f9fb8, 0xece62259, 0xecb9454a, 0xf94fc7eb, 
	0xdfcfa432, 0xec6626d3, 0xec3949c4, 0xf8cfcc65, 0xebe13ce3, 0xf877bf84, 0xf84ae275, 0x04e16515, 
	0xdf2c6040, 0xebc2e2e1, 0xeb9605d2, 0xf82c8873, 0xeb3df8f1, 0xf7d47b92, 0xf7a79e83, 0x043e2123, 
	0xeabdfd6b, 0xf754800c, 0xf727a2fd, 0x03be259d, 0xf6cf961c, 0x036618bc, 0x03393bad, 0x0fcfbe4e, 
	0xde6b9f3e, 0xeb0221df, 0xead544d0, 0xf76bc771, 0xea7d37ee, 0xf713ba8f, 0xf6e6dd80, 0x037d6020, 
	0xe9fd3c69, 0xf693bf0a, 0xf666e1fb, 0x02fd649b, 0xf60ed519, 0x02a557b9, 0x02787aaa, 0x0f0efd4b, 
	0xe959f877, 0xf5f07b18, 0xf5c39e09, 0x025a20a9, 0xf56b9127, 0x020213c7, 0x01d536b8, 0x0e6bb959, 
	0xf4eb95a2, 0x01821842, 0x01553b33, 0x0debbdd4, 0x00fd2e51, 0x0d93b0f2, 0x0d66d3e3, 0x19fd5684, 
	0xdd940383, 0xea2a8624, 0xe9fda915, 0xf6942bb6, 0xe9a59c34, 0xf63c1ed5, 0xf60f41c6, 0x02a5c466, 
	0xe925a0ae, 0xf5bc234f, 0xf58f4640, 0x0225c8e0, 0xf537395f, 0x01cdbbff, 0x01a0def0, 0x0e376191, 
	0xe8825cbc, 0xf518df5d, 0xf4ec024e, 0x018284ee, 0xf493f56d, 0x012a780d, 0x00fd9afe, 0x0d941d9f, 
	0xf413f9e7, 0x00aa7c87, 0x007d9f78, 0x0d142219, 0x00259297, 0x0cbc1538, 0x0c8f3829, 0x1925baca, 
	0xe7c19bb9, 0xf4581e5b, 0xf42b414c, 0x00c1c3ec, 0xf3d3346a, 0x0069b70a, 0x003cd9fb, 0x0cd35c9c, 
	0xf35338e4, 0xffe9bb85, 0xffbcde77, 0x0c536117, 0xff64d195, 0x0bfb5435, 0x0bce7726, 0x1864f9c7, 
	0xf2aff4f3, 0xff467794, 0xff199a85, 0x0bb01d25, 0xfec18da3, 0x0b581043, 0x0b2b3334, 0x17c1b5d5, 
	0xfe41921d, 0x0ad814be, 0x0aab37af, 0x1741ba50, 0x0a532acd, 0x16e9ad6e, 0x16bcd05f, 0x23535300, 
	0xdcacad00, 0xe9432fa1, 0xe9165292, 0xf5acd533, 0xe8be45b0, 0xf554c851, 0xf527eb42, 0x01be6de3, 
	0xe83e4a2b, 0xf4d4cccc, 0xf4a7efbd, 0x013e725d, 0xf44fe2db, 0x00e6657b, 0x00b9886c, 0x0d500b0d, 
	0xe79b0639, 0xf43188da, 0xf404abcb, 0x009b2e6b, 0xf3ac9ee9, 0x00432189, 0x0016447b, 0x0cacc71c, 
	0xf32ca364, 0xffc32605, 0xff9648f6, 0x0c2ccb96, 0xff3e3c14, 0x0bd4beb4, 0x0ba7e1a5, 0x183e6447, 
	0xe6da4536, 0xf370c7d7, 0xf343eac8, 0xffda6d69, 0xf2ebdde7, 0xff826088, 0xff558379, 0x0bec0619, 
	0xf26be261, 0xff026502, 0xfed587f3, 0x0b6c0a93, 0xfe7d7b12, 0x0b13fdb2, 0x0ae720a3, 0x177da344, 
	0xf1c89e6f, 0xfe5f2110, 0xfe324401, 0x0ac8c6a1, 0xfdda3720, 0x0a70b9c0, 0x0a43dcb1, 0x16da5f52, 
	0xfd5a3b9a, 0x09f0be3a, 0x09c3e12b, 0x165a63cc, 0x096bd44a, 0x160256eb, 0x15d579dc, 0x226bfc7d, 
	0xe602a97c, 0xf2992c1d, 0xf26c4f0e, 0xff02d1af, 0xf214422c, 0xfeaac4cd, 0xfe7de7be, 0x0b146a5e, 
	0xf19446a7, 0xfe2ac948, 0xfdfdec39, 0x0a946ed9, 0xfda5df57, 0x0a3c61f7, 0x0a0f84e8, 0x16a60789, 
	0xf0f102b5, 0xfd878556, 0xfd5aa847, 0x09f12ae7, 0xfd029b65, 0x09991e05, 0x096c40f6, 0x1602c397, 
	0xfc829fe0, 0x09192280, 0x08ec4571, 0x1582c812, 0x0894388f, 0x152abb30, 0x14fdde21, 0x219460c2, 
	0xf03041b2, 0xfcc6c453, 0xfc99e744, 0x093069e4, 0xfc41da63, 0x08d85d03, 0x08ab7ff4, 0x15420295, 
	0xfbc1dedd, 0x0858617d, 0x082b846e, 0x14c2070f, 0x07d3778d, 0x1469fa2e, 0x143d1d1f, 0x20d39fc0, 
	0xfb1e9aeb, 0x07b51d8b, 0x0788407c, 0x141ec31d, 0x0730339b, 0x13c6b63c, 0x1399d92d, 0x20305bce, 
	0x06b03815, 0x1346bab6, 0x1319dda7, 0x1fb06048, 0x12c1d0c6, 0x1f585367, 0x1f2b7658, 0x2bc1f8f9, 
	};

const int fir1_debug[48] = {

    492968,     883159,    1622893,    2714604,    4244465,    6298618,    8958056,   12291802, 
  16349840,   21157371,   26709144,   32964387,   39844119,   47230942,   54970680,   62876294, 
  70734588,   78315069,   85380123,   91696284,   97046165,  101239896,  104125129,  105595216, 
 105595216,  104125129,  101239896,   97046165,   91696284,   85380123,   78315069,   70734588, 
  62876294,   54970680,   47230942,   39844119,   32964387,   26709144,   21157371,   16349840, 
  12291802,    8958056,    6298618,    4244465,    2714604,    1622893,     883159,     492968, 
};
const int g_second_stage_fir32[16] = {
	0x0105503f,
	0x01343daa,
	0x01d88ec5,
	0x02a5390b,
	0x0399dd65,
	0x04b3a331,
	0x05ebefe1,
	0x073b0fb7,
	0x0895e6d8,
	0x09f055bf,
	0x0b3c7d7d,
	0x0c6c3644,
	0x0d723ba4,
	0x0e426978,
	0x0ed33161,
	0x0f1d633b,
};


const int g_sine_wave3[128] = {
	0x00000000, 0x02ECB69A, 0x05D79F74, 0x08BEEDEA, 0x0BA0D792, 0x0E7B9554, 0x114D6485, 0x141487FD,
	0x16CF4928, 0x197BF915, 0x1C18F181, 0x1EA495D8, 0x211D5439, 0x2381A668, 0x25D012C4, 0x28072D2B,
	0x2A2597DD, 0x2C2A0455, 0x2E133415, 0x2FDFF96B, 0x318F382C, 0x331FE662, 0x34910CF0, 0x35E1C82D,
	0x3711486D, 0x381ED281, 0x3909C030, 0x39D18095, 0x3A759880, 0x3AF5A2BE, 0x3B515057, 0x3B8868C0,
	0x3B9ACA00, 0x3B8868C0, 0x3B515057, 0x3AF5A2BE, 0x3A759880, 0x39D18095, 0x3909C030, 0x381ED281,
	0x3711486D, 0x35E1C82D, 0x34910CF0, 0x331FE662, 0x318F382C, 0x2FDFF96B, 0x2E133415, 0x2C2A0455,
	0x2A2597DD, 0x28072D2B, 0x25D012C4, 0x2381A668, 0x211D5439, 0x1EA495D8, 0x1C18F181, 0x197BF915,
	0x16CF4928, 0x141487FD, 0x114D6485, 0x0E7B9554, 0x0BA0D792, 0x08BEEDEA, 0x05D79F74, 0x02ECB69A,
	0x00000000, 0xFD134966, 0xFA28608C, 0xF7411216, 0xF45F286E, 0xF1846AAC, 0xEEB29B7B, 0xEBEB7803,
	0xE930B6D8, 0xE68406EB, 0xE3E70E7F, 0xE15B6A28, 0xDEE2ABC7, 0xDC7E5998, 0xDA2FED3C, 0xD7F8D2D5,
	0xD5DA6823, 0xD3D5FBAB, 0xD1ECCBEB, 0xD0200695, 0xCE70C7D4, 0xCCE0199E, 0xCB6EF310, 0xCA1E37D3,
	0xC8EEB793, 0xC7E12D7F, 0xC6F63FD0, 0xC62E7F6B, 0xC58A6780, 0xC50A5D42, 0xC4AEAFA9, 0xC4779740,
	0xC4653600, 0xC4779740, 0xC4AEAFA9, 0xC50A5D42, 0xC58A6780, 0xC62E7F6B, 0xC6F63FD0, 0xC7E12D7F,
	0xC8EEB793, 0xCA1E37D3, 0xCB6EF310, 0xCCE0199E, 0xCE70C7D4, 0xD0200695, 0xD1ECCBEB, 0xD3D5FBAB,
	0xD5DA6823, 0xD7F8D2D5, 0xDA2FED3C, 0xDC7E5998, 0xDEE2ABC7, 0xE15B6A28, 0xE3E70E7F, 0xE68406EB,
	0xE930B6D8, 0xEBEB7803, 0xEEB29B7B, 0xF1846AAC, 0xF45F286E, 0xF7411216, 0xFA28608C, 0xFD134966};
// {CRC polynominal to use, bogus data to checksum}
const int g_crc_constants[2] = {0xEDB88320, 0xFFFFFFFF};
const int fir2_debug[32] = {
   8562719,   10100437,   15484770,   22191237,   30207666,   39440792,   49674224,   60655579, 
  72020844,   83372767,   94256830,  104209186,  112795090,  119616700,  124360880,  126792093, 
 126792093,  124360880,  119616700,  112795090,  104209186,   94256830,   83372767,   72020844, 
  60655579,   49674224,   39440792,   30207666,   22191237,   15484770,   10100437,    8562719, 
};

const int g_third_stage_fir_40kHz[16] = {
	0x00063d55, 0x00077478, 0xffe34ea1, 0x003aa25d, 0xffa87b5a, 0x005d5234, 0xffcf9cde, 0xffbd1ae7, 
	0x00f81055, 0xfe392579, 0x0261270e, 0xfda4fffb, 0x0133134a, 0x01c79dfb, 0xf79490c0, 0x232a32a3, 
	};
const int g_third_stage_fir_32kHz[16] = {
	0x00174953, 0xffe42d7e, 0x00000000, 0x003aa25d, 0xffa87b5a, 0x00000000, 0x00b4956b, 0xff065842, 
	0x00000000, 0x01c6da87, 0xfd9ed8f2, 0x00000000, 0x047a0554, 0xf95b9d1f, 0x00000000, 0x232a32a3, 
	};
const int g_third_stage_fir_24kHz[16] = {
	0xffe8b6ad, 0xffe42d7e, 0x002731f7, 0x003aa25d, 0xffa87b5a, 0xff808560, 0x00b4956b, 0x00f9a7be, 
	0xfead2378, 0xfe392579, 0x0261270e, 0x0337b6a3, 0xfb85faac, 0xf95b9d1f, 0x0b8060dd, 0x232a32a3, 
	};
const int g_third_stage_fir_16kHz[16] = {
	0xffe8b6ad, 0x001bd282, 0x004e63ef, 0x003aa25d, 0xffa87b5a, 0xff010ac0, 0xff4b6a95, 0x00f9a7be, 
	0x02a5b910, 0x01c6da87, 0xfd9ed8f2, 0xf99092b9, 0xfb85faac, 0x06a462e1, 0x1700c1bb, 0x232a32a3, 
	};
const int g_third_stage_fir_12kHz[16] = {
	0xffe8b6ad, 0xffbcd4be, 0xffa15fdc, 0xffc55da3, 0x005784a6, 0x0133c2f5, 0x01b3f7b0, 0x00f9a7be, 
	0xfead2378, 0xfbb5e2dd, 0xfa416029, 0xfcc8495d, 0x047a0554, 0x10091876, 0x1bc45bb4, 0x232a32a3, 
	};
const int g_third_stage_fir_8kHz[16] = {
	0x0056e7fa, 0x0067d591, 0x006b154f, 0x003aa25d, 0xffa87b5a, 0xfea3b88b, 0xfd5e0d76, 0xfc5c461f, 
	0xfc62369a, 0xfe392579, 0x0261270e, 0x08ca6d4c, 0x10b50205, 0x18c9ed89, 0x1f6c30fb, 0x232a32a3, 
	};
