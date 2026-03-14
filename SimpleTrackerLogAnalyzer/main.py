#!/usr/bin/env python3
"""
GPS Tracker Log Analyzer
Main CLI application for parsing serial logs and generating KML visualizations.
"""

import argparse
import sys
from pathlib import Path

from modules.log_parser import LogParser
from modules.data_processor import DataProcessor
from modules.kml_generator import KMLGenerator
from modules.csv_exporter import CSVExporter


def main():
    """Main application entry point."""
    
    parser = argparse.ArgumentParser(
        description='Parse GPS tracker serial logs and generate KML visualizations',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py log.txt output.kml
  python main.py log.txt output.kml --min-hdop 2.0 --min-rssi -80
  python main.py log.txt output.kml -v --comparison local_log.txt
        """
    )
    
    parser.add_argument(
        'log_file',
        help='Input serial log file'
    )
    
    parser.add_argument(
        'output_file',
        nargs='?',
        default=None,
        help='Output KML file (default: output/<log_file_base>.kml)'
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    
    parser.add_argument(
        '--min-hdop',
        type=float,
        default=None,
        help='Minimum HDOP threshold (lower is better, default: no filter)'
    )
    
    parser.add_argument(
        '--min-rssi',
        type=int,
        default=None,
        help='Minimum RSSI threshold in dBm (higher is better, default: no filter)'
    )
    
    parser.add_argument(
        '--comparison',
        type=str,
        default=None,
        help='Local tracker log file for comparison visualization'
    )
    
    parser.add_argument(
        '--no-color-rssi',
        action='store_true',
        help='Disable RSSI-based coloring in KML'
    )
    
    args = parser.parse_args()
    
    # Validate input file
    log_path = Path(args.log_file)
    if not log_path.exists():
        print(f"Error: Log file not found: {args.log_file}", file=sys.stderr)
        return 1
    
    # Determine output file
    if args.output_file:
        output_path = Path(args.output_file)
    else:
        output_dir = Path('output')
        output_dir.mkdir(exist_ok=True)
        output_path = output_dir / f"{log_path.stem}.kml"
    
    # Ensure output directory exists
    output_path.parent.mkdir(exist_ok=True, parents=True)
    
    if args.verbose:
        print(f"Processing log file: {log_path}")
        print(f"Output file: {output_path}")
        if args.min_hdop:
            print(f"Min HDOP filter: {args.min_hdop}")
        if args.min_rssi:
            print(f"Min RSSI filter: {args.min_rssi} dBm")
    
    try:
        # Parse log file
        if args.verbose:
            print("\n[1/3] Parsing log file...")
        
        log_parser = LogParser(str(log_path), verbose=args.verbose)
        if not log_parser.read_log_file():
            return 1
        
        if not log_parser.parse():
            return 1
        
        # Process data
        if args.verbose:
            print("[2/3] Processing data...")
        
        processor = DataProcessor(verbose=args.verbose)
        
        remote_responses = log_parser.get_remote_responses()
        remote_df = processor.process_remote_responses(
            remote_responses,
            min_hdop=args.min_hdop,
            min_rssi=args.min_rssi
        )
        
        if args.verbose and not remote_df.empty:
            print(f"  Remote trackers found: {', '.join(processor.get_devices(remote_df))}")
            for uid in processor.get_devices(remote_df):
                device_df = processor.get_device_data(remote_df, uid)
                stats = processor.get_track_statistics(device_df)
                print(f"  {uid}: {stats['num_points']} points, "
                      f"alt: {stats['min_altitude']:.1f}m - {stats['max_altitude']:.1f}m")
        
        # Generate KML
        if args.verbose:
            print("[3/3] Generating KML...")
        
        kml_gen = KMLGenerator(verbose=args.verbose)
        
        # Check if we have comparison data
        if args.comparison:
            comparison_path = Path(args.comparison)
            if not comparison_path.exists():
                print(f"Error: Comparison log file not found: {args.comparison}", file=sys.stderr)
                return 1
            
            if args.verbose:
                print(f"  Loading comparison local log: {args.comparison}")
            
            local_parser = LogParser(str(comparison_path), verbose=False)
            if not local_parser.read_log_file() or not local_parser.parse():
                print(f"Error: Could not parse comparison log file", file=sys.stderr)
                return 1
            
            local_responses = local_parser.get_local_responses()
            local_df = processor.process_local_responses(local_responses, min_hdop=args.min_hdop)
            
            # Generate comparison KML
            if not kml_gen.generate_comparison_kml(remote_df, local_df, str(output_path)):
                return 1
            
            # Export comparison CSV
            if args.verbose:
                print("[4/4] Exporting CSV files...")
            
            csv_exporter = CSVExporter(verbose=args.verbose)
            csv_base = str(output_path).replace('.kml', '')
            if not csv_exporter.export_comparison_csv(remote_df, local_df, f"{csv_base}.csv"):
                return 1
        else:
            # Generate remote-only KML
            if remote_df.empty:
                print("Error: No remote data to visualize", file=sys.stderr)
                return 1
            
            color_by_rssi = not args.no_color_rssi
            if not kml_gen.generate_remote_track_kml(
                remote_df,
                str(output_path),
                color_by_rssi=color_by_rssi
            ):
                return 1
            
            # Export CSV
            if args.verbose:
                print("[4/4] Exporting CSV file...")
            
            csv_exporter = CSVExporter(verbose=args.verbose)
            csv_file = str(output_path).replace('.kml', '.csv')
            if not csv_exporter.export_remote_track_csv(remote_df, csv_file):
                return 1
        
        print(f"\nSuccess! Files created:")
        kml_file = output_path
        csv_file = str(output_path).replace('.kml', '.csv')
        if args.comparison:
            csv_remote = str(output_path).replace('.kml', '_remote.csv')
            csv_local = str(output_path).replace('.kml', '_local.csv')
            print(f"  KML: {kml_file}")
            print(f"  CSV (Remote): {csv_remote}")
            print(f"  CSV (Local): {csv_local}")
        else:
            print(f"  KML: {kml_file}")
            print(f"  CSV: {csv_file}")
        return 0
    
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
