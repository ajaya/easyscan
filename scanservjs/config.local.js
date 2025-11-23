// scanservjs local configuration
// This file extends the default configuration and sets default values

module.exports = {
  afterConfig: function(config) {
    // Set default paper size to Letter
    // This will be the default selected paper size in the UI
    if (config.paperSizes) {
      const letterSize = config.paperSizes.find(p => p.name === "Letter");
      if (letterSize) {
        config.defaultPaperSize = letterSize;
      }
    }
    
    // Set default source to ADF Simplex
    // This sets the default scanner source (platen vs ADF)
    config.defaultSource = "adf-simplex";
    
    // Set default scan mode (Color, Gray, or Lineart)
    // Uncomment and modify as needed:
    // config.defaultScanMode = "Color";
    
    // Set default resolution in DPI
    // Uncomment and modify as needed:
    // config.defaultResolution = 300;
    
    // Set default duplex mode (if scanner supports it)
    // config.defaultDuplex = false; // false = simplex, true = duplex
    
    return config;
  }
};

