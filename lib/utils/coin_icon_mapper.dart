import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class CoinIconMapper {
  static const Map<String, String> _coinIconMap = {
    'BTC': 'assets/images/btc.png',
    'ETH': 'assets/images/eth.png',
    'SOL': 'assets/images/sol.png',
    'ADA': 'assets/images/ada.png',
    'BNB': 'assets/images/bnb.png',
    'DOT': 'assets/images/dot.png',
    'USDT': 'assets/images/usdt.png',
    'USDC': 'assets/images/usdc.png',
    'BUSD': 'assets/images/busd.png',
    'XRP': 'assets/images/xrp.png',
    'LTC': 'assets/images/ltc.png',
    'BCH': 'assets/images/bch.png',
    'LINK': 'assets/images/link.png',
    'UNI': 'assets/images/uni.png',
    'AVAX': 'assets/images/avax.png',
    'MATIC': 'assets/images/matic.png',
    'ATOM': 'assets/images/atom.png',
    'NEAR': 'assets/images/near.png',
    'ALGO': 'assets/images/algo.png',
    'VET': 'assets/images/vet.png',
    'FTM': 'assets/images/ftm.png',
    'AAVE': 'assets/images/aave.png',
    'MKR': 'assets/images/mkr.png',
    'COMP': 'assets/images/comp.png',
    'SUSHI': 'assets/images/sushi.png',
    'YFI': 'assets/images/yfi.png',
    'SNX': 'assets/images/snx.png',
    'CRV': 'assets/images/crv.png',
    'BAL': 'assets/images/bal.png',
    'REN': 'assets/images/ren.png',
    'KNC': 'assets/images/knc.png',
    'ZRX': 'assets/images/zrx.png',
    'BAT': 'assets/images/bat.png',
    'ENJ': 'assets/images/enj.png',
    'MANA': 'assets/images/mana.png',
    'SAND': 'assets/images/sand.png',
    'AXS': 'assets/images/axs.png',
    'SHIB': 'assets/images/shib.png',
    'DOGE': 'assets/images/doge.png',
    'LUNA': 'assets/images/luna.png',
    'ICP': 'assets/images/icp.png',
    'HBAR': 'assets/images/hbar.png',
    'ALPH': 'assets/images/alph.png',
    'FLOW': 'assets/images/flow.png',
    'ROSE': 'assets/images/rose.png',
    'CELO': 'assets/images/celo.png',
    'MINA': 'assets/images/mina.png',
    'IMX': 'assets/images/imx.png',
    'GALA': 'assets/images/gala.png',
    'LRC': 'assets/images/lrc.png',
    'CHZ': 'assets/images/chz.png',
    'STX': 'assets/images/stx.png',
    'AR': 'assets/images/ar.png',
    'RNDR': 'assets/images/rndr.png',
    'THETA': 'assets/images/theta.png',
    'TFUEL': 'assets/images/tfuel.png',
  };

  static String getCoinIconPath(String symbol) {
    final upperSymbol = symbol.toUpperCase();
    // Direct lookup for stablecoins and exact matches
    if (_coinIconMap.containsKey(upperSymbol)) {
      return _coinIconMap[upperSymbol]!;
    }
    // For trading pairs like BTCUSDT, extract the base coin
    final cleanedSymbol = upperSymbol.replaceAll('USDT', '').replaceAll('USDC', '').replaceAll('BUSD', '');
    return _coinIconMap[cleanedSymbol] ?? '';
  }

  static bool hasCoinIcon(String symbol) {
    final upperSymbol = symbol.toUpperCase();
    // Direct check for exact matches
    if (_coinIconMap.containsKey(upperSymbol)) {
      return true;
    }
    // For trading pairs
    final cleanedSymbol = upperSymbol.replaceAll('USDT', '').replaceAll('USDC', '').replaceAll('BUSD', '');
    return _coinIconMap.containsKey(cleanedSymbol);
  }

  static Widget getCoinIcon(String symbol, {double size = 24, Color? fallbackColor}) {
    final iconPath = getCoinIconPath(symbol);
    
    debugPrint('CoinIconMapper: Getting icon for $symbol, path: $iconPath');
    
    if (iconPath.isNotEmpty) {
      return Image.asset(
        iconPath,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('CoinIconMapper: Error loading $iconPath: $error');
          return _buildFallbackIcon(symbol, size, fallbackColor);
        },
      );
    } else {
      debugPrint('CoinIconMapper: No icon path found for $symbol');
      return _buildFallbackIcon(symbol, size, fallbackColor);
    }
  }

  static Widget _buildFallbackIcon(String symbol, double size, Color? color) {
    final displaySymbol = symbol.toUpperCase().replaceAll('USDT', '').replaceAll('USDC', '').replaceAll('BUSD', '');
    final colors = [
      const Color(0xFF84BD00),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
    ];
    
    final bgColor = color ?? colors[displaySymbol.hashCode % colors.length];
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          displaySymbol.length > 2 ? displaySymbol.substring(0, 2) : displaySymbol,
          style: TextStyle(
            color: bgColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static List<String> getAvailableCoins() {
    return _coinIconMap.keys.toList();
  }
}
