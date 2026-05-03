public enum A {
    public static let gain = AudioGainFactory()
    public static let gate = AudioGateFactory()
    public static let leveller = AudioLevellerFactory()
    public static let compressor = AudioCompressorFactory()
    public static let equalizer = AudioEqualizerFactory()
    public static let deesser = AudioDeEsserFactory()
    public static let limiter = AudioLimiterFactory()
}
