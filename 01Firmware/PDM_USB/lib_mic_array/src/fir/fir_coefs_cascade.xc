// Copyright (c) 2026, XMOS Ltd, All rights reserved
// Copyright (c) 2026, SoundThinking Inc.
const float g_second_to_third_fir31_48kHz_gain = 0.7060080090012524;

const int g_second_to_third_fir31_48kHz_gain_scaling_factor = 1;

const int g_second_to_third_fir31_48kHz[32] = {
    0xffff32e9, 0x00000000, 0x000755f4, 0x00000000, 0xffdbe41b, 0x00000000, 0x007dfe79, 0x00000000,
    0xfea0e773, 0x00000000, 0x035352c5, 0x00000000, 0xf81b9fa7, 0x00000000, 0x1c275895, 0x2d2f3ca5,
    0x1c275895, 0x00000000, 0xf81b9fa7, 0x00000000, 0x035352c5, 0x00000000, 0xfea0e773, 0x00000000,
    0x007dfe79, 0x00000000, 0xffdbe41b, 0x00000000, 0x000755f4, 0x00000000, 0xffff32e9, 0x00000000,
    };

const int g_second_to_third_fir31_48kHz_debug[32] = {
        -52503,          0,     480756,          0,   -2366437,          0,    8257145,          0,
     -23009421,          0,   55792325,          0, -132407385,          0,  472340629,  758070437,
     472340629,          0, -132407385,          0,   55792325,          0,  -23009421,          0,
       8257145,          0,   -2366437,          0,     480756,          0,     -52503,          0,
    };

const float g_third_to_output_fir31_40kHz_gain = 0.551773417218275;

const int g_third_to_output_fir31_40kHz_gain_scaling_factor = 1;

const int g_third_to_output_fir31_40kHz[32] = {
    0x0044d943, 0x01d3a2fc, 0xffb8c0d0, 0xfed29d66, 0xffd0d4bc, 0x01951c2c, 0x00bbe260, 0xfe08e0a8,
    0xfe5b2e55, 0x02503ce5, 0x0334f1d8, 0xfd6840c4, 0xf97f9e0b, 0x02c545ff, 0x156274b4, 0x1f2378f6,
    0x156274b4, 0x02c545ff, 0xf97f9e0b, 0xfd6840c4, 0x0334f1d8, 0x02503ce5, 0xfe5b2e55, 0xfe08e0a8,
    0x00bbe260, 0x01951c2c, 0xffd0d4bc, 0xfed29d66, 0xffb8c0d0, 0x01d3a2fc, 0x0044d943, 0x00000000,
    };

const int g_third_to_output_fir31_40kHz_debug[32] = {
       4512067,   30647036,   -4669232,  -19751578,   -3091268,   26549292,   12313184,  -32972632,
     -27578795,   38812901,   53801432,  -43499324, -109076981,   46482943,  358773940,  522418422,
     358773940,   46482943, -109076981,  -43499324,   53801432,   38812901,  -27578795,  -32972632,
      12313184,   26549292,   -3091268,  -19751578,   -4669232,   30647036,    4512067,          0,
    };

const float g_third_to_output_fir31_24kHz_gain = 0.6191016562665285;

const int g_third_to_output_fir31_24kHz_gain_scaling_factor = 1;

const int g_third_to_output_fir31_24kHz[32] = {
    0x005915b9, 0x00d7b1a8, 0x0005a01c, 0xff5bda3a, 0xfec7a7a3, 0xff7088c9, 0x0107c59a, 0x0247a619,
    0x018dc3e7, 0xfea7e69a, 0xfba8459a, 0xfbeb776f, 0x018fcbc3, 0x0b4e7e76, 0x14a171ca, 0x1878b64f,
    0x14a171ca, 0x0b4e7e76, 0x018fcbc3, 0xfbeb776f, 0xfba8459a, 0xfea7e69a, 0x018dc3e7, 0x0247a619,
    0x0107c59a, 0xff7088c9, 0xfec7a7a3, 0xff5bda3a, 0x0005a01c, 0x00d7b1a8, 0x005915b9, 0x00000000,
    };

const int g_third_to_output_fir31_24kHz_debug[32] = {
       5838265,   14135720,     368668,  -10757574,  -20469853,   -9402167,   17286554,   38250009,
      26067943,  -22550886,  -72858214,  -68454545,   26201027,  189693558,  346124746,  410564175,
     346124746,  189693558,   26201027,  -68454545,  -72858214,  -22550886,   26067943,   38250009,
      17286554,   -9402167,  -20469853,  -10757574,     368668,   14135720,    5838265,          0,
    };

const float g_third_to_output_fir31_16kHz_gain = 0.6685013466246463;

const int g_third_to_output_fir31_16kHz_gain_scaling_factor = 1;

const int g_third_to_output_fir31_16kHz[32] = {
    0xff47d3d9, 0xffb20eaa, 0x001f35a8, 0x00cd6e0d, 0x015eee8c, 0x015b8909, 0x00767d68, 0xfed61905,
    0xfd2c63c3, 0xfc8752e3, 0xfde0aac5, 0x0198c3c5, 0x0724ddac, 0x0d1cf5a1, 0x11b50a84, 0x136e4546,
    0x11b50a84, 0x0d1cf5a1, 0x0724ddac, 0x0198c3c5, 0xfde0aac5, 0xfc8752e3, 0xfd2c63c3, 0xfed61905,
    0x00767d68, 0x015b8909, 0x015eee8c, 0x00cd6e0d, 0x001f35a8, 0xffb20eaa, 0xff47d3d9, 0x00000000,
    };

const int g_third_to_output_fir31_16kHz_debug[32] = {
     -12069927,   -5108054,    2045352,   13463053,   22998668,   22776073,    7765352,  -19523323,
     -47422525,  -58240285,  -35607867,   26788805,  119856556,  220001697,  297077380,  325993798,
     297077380,  220001697,  119856556,   26788805,  -35607867,  -58240285,  -47422525,  -19523323,
       7765352,   22776073,   22998668,   13463053,    2045352,   -5108054,  -12069927,          0,
    };

const float g_third_to_output_fir31_12kHz_gain = 0.71846987906429;

const int g_third_to_output_fir31_12kHz_gain_scaling_factor = 1;

const int g_third_to_output_fir31_12kHz[32] = {
    0xffc6d0d7, 0x001f09b1, 0x006cfc4c, 0x00bfecde, 0x00d23eb1, 0x0061c560, 0xff5f2aed, 0xfe1313c3,
    0xfd2042d7, 0xfd540791, 0xff505a9e, 0x03328a5a, 0x0863a5b0, 0x0db02026, 0x11a779cd, 0x131fe73a,
    0x11a779cd, 0x0db02026, 0x0863a5b0, 0x03328a5a, 0xff505a9e, 0xfd540791, 0xfd2042d7, 0xfe1313c3,
    0xff5f2aed, 0x0061c560, 0x00d23eb1, 0x00bfecde, 0x006cfc4c, 0x001f09b1, 0xffc6d0d7, 0x00000000,
    };

const int g_third_to_output_fir31_12kHz_debug[32] = {
      -3747625,    2034097,    7142476,   12578014,   13778609,    6407520,  -10540307,  -32304189,
     -48217385,  -44824687,  -11511138,   53643866,  140748208,  229646374,  296188365,  320857914,
     296188365,  229646374,  140748208,   53643866,  -11511138,  -44824687,  -48217385,  -32304189,
     -10540307,    6407520,   13778609,   12578014,    7142476,    2034097,   -3747625,          0,
    };

const float g_third_to_output_fir31_8kHz_gain = 0.7594969503823223;

const int g_third_to_output_fir31_8kHz_gain_scaling_factor = 1;

const int g_third_to_output_fir31_8kHz[32] = {
    0x00608b3d, 0x00634b5f, 0x005a4a20, 0x0010da90, 0xff804c33, 0xfec1ed93, 0xfe1378bb, 0xfdce0dc0,
    0xfe4f616a, 0xffdaaae5, 0x027acd26, 0x05f1c3d5, 0x09bc2667, 0x0d2bfab5, 0x0f928d8d, 0x106f232d,
    0x0f928d8d, 0x0d2bfab5, 0x09bc2667, 0x05f1c3d5, 0x027acd26, 0xffdaaae5, 0xfe4f616a, 0xfdce0dc0,
    0xfe1378bb, 0xfec1ed93, 0xff804c33, 0x0010da90, 0x005a4a20, 0x00634b5f, 0x00608b3d, 0x00000000,
    };

const int g_third_to_output_fir31_8kHz_debug[32] = {
       6327101,    6507359,    5917216,    1104528,   -8369101,  -20845165,  -32278341,  -36827712,
     -28352150,   -2446619,   41602342,   99730389,  163325543,  220986037,  261262733,  275718957,
     261262733,  220986037,  163325543,   99730389,   41602342,   -2446619,  -28352150,  -36827712,
     -32278341,  -20845165,   -8369101,    1104528,    5917216,    6507359,    6327101,          0,
    };

