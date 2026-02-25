#!/usr/bin/env python3
"""
MatriculaUp PDF Extractor
Usage:
  python scripts/extract.py --type courses --pdf <path>
  python scripts/extract.py --type curriculum --pdf <path>
"""
import argparse
import sys
from pathlib import Path

# Add project root to path so 'scripts.extractors' imports work
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.extractors.courses import CourseOfferingExtractor


def main():
    parser = argparse.ArgumentParser(description="MatriculaUp PDF Extractor")
    parser.add_argument("--type", required=True, choices=["courses", "curriculum"],
                        help="Type of PDF to extract")
    parser.add_argument("--pdf", required=True, help="Path to PDF file")
    parser.add_argument("--output-dir", default="input", help="Output directory (default: input/)")
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    if not pdf_path.exists():
        print(f"x PDF not found: {pdf_path}", file=sys.stderr)
        sys.exit(1)

    if args.type == "courses":
        extractor = CourseOfferingExtractor(str(pdf_path), args.output_dir)
    elif args.type == "curriculum":
        # Plan 03 implements CurriculumExtractor -- import lazily to avoid import error
        try:
            from scripts.extractors.curriculum import CurriculumExtractor
            extractor = CurriculumExtractor(str(pdf_path), args.output_dir)
        except ImportError:
            print("x Curriculum extractor not yet implemented", file=sys.stderr)
            sys.exit(1)

    data = extractor.extract()
    out_path = extractor.save(data)
    print(f"Output written to {out_path}")

    if extractor.error_rate() > 0.01:
        print(f"  Error rate {extractor.error_rate():.1%} exceeds threshold", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
