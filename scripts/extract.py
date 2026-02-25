"""
MatriculaUp extraction CLI.

Usage:
  python scripts/extract.py --type courses   --pdf pdfs/matricula/2026-1/regular/Oferta-Academica-2026-I_v1.pdf
  python scripts/extract.py --type curriculum --pdf "pdfs/plan_estudios/econom\u00eda/2017/2017_Plan-de-Estudios-Economia-2017-Cursos_30.10.2020-1.pdf"

Output is written to: input/
  courses   -> input/courses_2026-1.json
  curriculum -> input/curricula_economia2017.json
"""
import argparse
import sys
import os
import logging

# Ensure the project root is in sys.path so 'scripts.extractors' resolves
# when this file is invoked directly (python scripts/extract.py ...)
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(
        description="Extract structured JSON data from UP academic PDFs.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--type",
        required=True,
        choices=["courses", "curriculum"],
        help="Extraction type: 'courses' for schedule PDF, 'curriculum' for plan de estudios PDF.",
    )
    parser.add_argument(
        "--pdf",
        required=True,
        help="Path to the input PDF file.",
    )
    parser.add_argument(
        "--output-dir",
        default="input",
        help="Directory where JSON output is written (default: input/).",
    )
    args = parser.parse_args()

    if args.type == "courses":
        try:
            from scripts.extractors.courses import CoursesExtractor
        except ImportError:
            logger.error("CoursesExtractor not yet implemented. Run Plan 02 first.")
            sys.exit(1)
        extractor = CoursesExtractor(args.pdf, args.output_dir)

    elif args.type == "curriculum":
        from scripts.extractors.curriculum import CurriculumExtractor
        extractor = CurriculumExtractor(args.pdf, args.output_dir)

    else:
        logger.error("Unknown extraction type: %s", args.type)
        sys.exit(1)

    data = extractor.extract()
    output_path = extractor.save(data)
    print(f"Output written to: {output_path}")

    error_rate = extractor.error_rate()
    if error_rate > 0.01:
        logger.warning(
            "Error rate %.1f%% exceeds 1%% threshold -- review output carefully.",
            error_rate * 100,
        )
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
