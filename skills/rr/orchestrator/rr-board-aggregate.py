#!/usr/bin/env python3
"""
rr-board-aggregate.py — Aggregate risk assessment data for Board paper generation.

Reads all individual assessment files from ~/rr-work/individual/ and produces
a single board-statistics.json with comprehensive statistics for the Board paper.

Usage:
    python3 rr-board-aggregate.py --work-dir ~/rr-work --quarter Q1 [--year 2026]

Handles two assessment JSON shapes:
  - Nested: assessment.sections.header, assessment.sections.inherent_risk, etc.
  - Flat:   assessment.header, assessment.inherent_risk, etc.
"""

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

CATEGORY_NAMES = {
    "A": "Audit",
    "B": "Business Continuity Management",
    "C": "Compliance",
    "D": "Product/Design",
    "ER": "Expansion Risk",
    "F": "Financial",
    "I": "Investment",
    "L": "Legal",
    "O": "Operational",
    "OO": "Other Operational",
    "P": "People",
    "T": "Technology",
}

RATING_ORDER = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}

RATING_MATRIX = {
    ("High", "High"): "Critical",
    ("High", "Medium"): "High",
    ("High", "Low"): "Medium",
    ("Medium", "High"): "High",
    ("Medium", "Medium"): "Medium",
    ("Medium", "Low"): "Low",
    ("Low", "High"): "Medium",
    ("Low", "Medium"): "Low",
    ("Low", "Low"): "Low",
}


def normalise_sections(assessment_entry):
    """Extract sections from either nested or flat assessment structure."""
    assessment = assessment_entry.get("assessment", assessment_entry)

    if "sections" in assessment and isinstance(assessment["sections"], dict):
        return assessment["sections"], assessment.get("metadata", {})

    # Flat structure: sections are directly on the assessment object
    section_keys = [
        "header", "context", "regulatory_framework", "inherent_risk",
        "existing_controls", "residual_risk", "recommendations", "evidences",
    ]
    sections = {k: assessment[k] for k in section_keys if k in assessment}
    metadata = assessment.get("metadata", {})
    return sections, metadata


def load_assessments(individual_dir):
    """Load all individual assessment files, normalising data shapes."""
    assessments = []
    errors = []

    for filepath in sorted(Path(individual_dir).glob("RR-*.json")):
        try:
            with open(filepath) as f:
                data = json.load(f)

            sections, metadata = normalise_sections(data)

            if not sections.get("header"):
                errors.append(f"{filepath.name}: missing header section")
                continue

            assessments.append({
                "risk_key": sections["header"].get("risk_id", filepath.stem),
                "sections": sections,
                "metadata": metadata,
                "adversarial_summary": data.get("adversarial_summary", {}),
            })
        except (json.JSONDecodeError, KeyError) as e:
            errors.append(f"{filepath.name}: {e}")

    return assessments, errors


def compute_rating_distributions(assessments):
    """Compute inherent and residual rating distributions."""
    inherent = Counter()
    residual = Counter()

    for a in assessments:
        ir = a["sections"].get("inherent_risk", {})
        rr = a["sections"].get("residual_risk", {})
        if ir.get("rating"):
            inherent[ir["rating"]] += 1
        if rr.get("rating"):
            residual[rr["rating"]] += 1

    return (
        {r: inherent.get(r, 0) for r in RATING_ORDER},
        {r: residual.get(r, 0) for r in RATING_ORDER},
    )


def compute_heatmaps(assessments):
    """Compute 3x3 likelihood x impact heatmaps."""
    levels = ["Low", "Medium", "High"]
    inherent_hm = defaultdict(int)
    residual_hm = defaultdict(int)

    for a in assessments:
        ir = a["sections"].get("inherent_risk", {})
        rr = a["sections"].get("residual_risk", {})

        if ir.get("likelihood") and ir.get("impact"):
            key = f"{ir['likelihood']}_{ir['impact']}"
            inherent_hm[key] += 1

        if rr.get("likelihood") and rr.get("impact"):
            key = f"{rr['likelihood']}_{rr['impact']}"
            residual_hm[key] += 1

    result = {}
    for prefix, hm in [("inherent", inherent_hm), ("residual", residual_hm)]:
        result[prefix] = {}
        for l in levels:
            for i in levels:
                k = f"{l}_{i}"
                result[prefix][k] = hm.get(k, 0)

    return result


def compute_category_breakdown(assessments):
    """Compute per-category statistics."""
    cats = defaultdict(lambda: {
        "count": 0,
        "inherent_dist": Counter(),
        "residual_dist": Counter(),
        "controls_count": 0,
        "recommendations_count": 0,
        "risk_keys": [],
    })

    for a in assessments:
        header = a["sections"].get("header", {})
        cat = header.get("risk_category", "?")

        cats[cat]["count"] += 1
        cats[cat]["risk_keys"].append(a["risk_key"])

        ir = a["sections"].get("inherent_risk", {})
        rr = a["sections"].get("residual_risk", {})
        if ir.get("rating"):
            cats[cat]["inherent_dist"][ir["rating"]] += 1
        if rr.get("rating"):
            cats[cat]["residual_dist"][rr["rating"]] += 1

        controls = a["sections"].get("existing_controls", [])
        if isinstance(controls, list):
            cats[cat]["controls_count"] += len(controls)

        recs = a["sections"].get("recommendations", [])
        if isinstance(recs, list):
            cats[cat]["recommendations_count"] += len(recs)

    result = {}
    for cat in sorted(cats.keys()):
        d = cats[cat]
        result[cat] = {
            "name": CATEGORY_NAMES.get(cat, cat),
            "count": d["count"],
            "inherent_dist": {r: d["inherent_dist"].get(r, 0) for r in RATING_ORDER},
            "residual_dist": {r: d["residual_dist"].get(r, 0) for r in RATING_ORDER},
            "controls_count": d["controls_count"],
            "recommendations_count": d["recommendations_count"],
            "risk_keys": d["risk_keys"],
        }

    return result


def extract_critical_high_risks(assessments):
    """Extract full details for Critical and High residual risks."""
    critical_high = []

    for a in assessments:
        rr = a["sections"].get("residual_risk", {})
        rating = rr.get("rating", "")
        if rating not in ("Critical", "High"):
            continue

        header = a["sections"].get("header", {})
        ir = a["sections"].get("inherent_risk", {})
        controls = a["sections"].get("existing_controls", [])
        recs = a["sections"].get("recommendations", [])
        context = a["sections"].get("context", {})

        critical_high.append({
            "risk_key": a["risk_key"],
            "risk_name": header.get("risk_name", ""),
            "risk_statement": header.get("risk_statement", ""),
            "category": header.get("risk_category", ""),
            "category_name": header.get("risk_category_name", ""),
            "inherent_likelihood": ir.get("likelihood", ""),
            "inherent_impact": ir.get("impact", ""),
            "inherent_rating": ir.get("rating", ""),
            "inherent_likelihood_rationale": ir.get("likelihood_rationale", ""),
            "inherent_impact_rationale": ir.get("impact_rationale", ""),
            "residual_likelihood": rr.get("likelihood", ""),
            "residual_impact": rr.get("impact", ""),
            "residual_rating": rr.get("rating", ""),
            "residual_likelihood_rationale": rr.get("likelihood_rationale", ""),
            "residual_impact_rationale": rr.get("impact_rationale", ""),
            "control_effect_summary": rr.get("control_effect_summary", ""),
            "narrative": context.get("narrative", ""),
            "business_relevance": context.get("business_relevance", []),
            "materiality_rationale": context.get("materiality_rationale", ""),
            "controls": [
                {
                    "id": c.get("id", ""),
                    "description": c.get("description", ""),
                    "control_type": c.get("control_type", ""),
                    "effectiveness": c.get("effectiveness", ""),
                    "effectiveness_rationale": c.get("effectiveness_rationale", ""),
                    "gaps": c.get("gaps", []),
                    "requires_verification": c.get("requires_verification", False),
                }
                for c in (controls if isinstance(controls, list) else [])
            ],
            "recommendations": [
                {
                    "id": r.get("id", ""),
                    "action": r.get("action", ""),
                    "priority": r.get("priority", ""),
                    "suggested_owner": r.get("suggested_owner", ""),
                    "suggested_deadline": r.get("suggested_deadline", ""),
                    "expected_outcome": r.get("expected_outcome", ""),
                    "regulatory_basis": r.get("regulatory_basis", ""),
                }
                for r in (recs if isinstance(recs, list) else [])
            ],
        })

    # Sort: Critical first, then High; within each, by risk key
    critical_high.sort(key=lambda x: (RATING_ORDER.get(x["residual_rating"], 9), x["risk_key"]))
    return critical_high


def compute_control_analysis(assessments):
    """Aggregate control effectiveness statistics."""
    total = 0
    by_effectiveness = Counter()
    by_type = Counter()
    requires_verification = 0

    for a in assessments:
        controls = a["sections"].get("existing_controls", [])
        if not isinstance(controls, list):
            continue
        for c in controls:
            total += 1
            eff = c.get("effectiveness", "Uncertain")
            by_effectiveness[eff] += 1
            ct = c.get("control_type", "Unknown")
            by_type[ct] += 1
            if c.get("requires_verification", False):
                requires_verification += 1

    effectiveness_labels = ["Effective", "Partially Effective", "Ineffective", "Uncertain"]
    type_labels = ["Preventive", "Detective", "Corrective"]

    return {
        "total_controls": total,
        "by_effectiveness": {e: by_effectiveness.get(e, 0) for e in effectiveness_labels},
        "by_type": {t: by_type.get(t, 0) for t in type_labels},
        "requires_verification_count": requires_verification,
    }


def compute_recommendation_analysis(assessments):
    """Aggregate recommendation statistics and extract top 20."""
    total = 0
    by_priority = Counter()
    by_owner = Counter()
    by_deadline = Counter()
    all_recs = []

    for a in assessments:
        recs = a["sections"].get("recommendations", [])
        if not isinstance(recs, list):
            continue
        for r in recs:
            total += 1
            priority = r.get("priority", "Medium")
            by_priority[priority] += 1
            owner = r.get("suggested_owner", "Unassigned")
            by_owner[owner] += 1
            deadline = r.get("suggested_deadline", "")
            if deadline:
                by_deadline[deadline] += 1

            all_recs.append({
                "risk_key": a["risk_key"],
                "risk_name": a["sections"].get("header", {}).get("risk_name", ""),
                "rec_id": r.get("id", ""),
                "action": r.get("action", ""),
                "priority": priority,
                "suggested_owner": owner,
                "suggested_deadline": deadline,
                "expected_outcome": r.get("expected_outcome", ""),
                "regulatory_basis": r.get("regulatory_basis", ""),
            })

    # Sort by priority (High first), then risk key
    priority_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}
    all_recs.sort(key=lambda x: (priority_order.get(x["priority"], 9), x["risk_key"]))

    return {
        "total_recommendations": total,
        "by_priority": {p: by_priority.get(p, 0) for p in ["Critical", "High", "Medium", "Low"]},
        "by_owner": dict(by_owner.most_common()),
        "by_deadline_quarter": dict(by_deadline.most_common()),
        "top_20": all_recs[:20],
    }


def compute_all_risks_summary(assessments):
    """Build summary table of all risks for appendix."""
    summary = []

    for a in assessments:
        header = a["sections"].get("header", {})
        ir = a["sections"].get("inherent_risk", {})
        rr = a["sections"].get("residual_risk", {})
        recs = a["sections"].get("recommendations", [])

        summary.append({
            "key": a["risk_key"],
            "name": header.get("risk_name", ""),
            "category": header.get("risk_category", ""),
            "category_name": header.get("risk_category_name", ""),
            "inherent_rating": ir.get("rating", ""),
            "residual_rating": rr.get("rating", ""),
            "inherent_likelihood": ir.get("likelihood", ""),
            "inherent_impact": ir.get("impact", ""),
            "residual_likelihood": rr.get("likelihood", ""),
            "residual_impact": rr.get("impact", ""),
            "recs_count": len(recs) if isinstance(recs, list) else 0,
        })

    # Sort by residual rating (Critical first), then category, then key
    summary.sort(key=lambda x: (
        RATING_ORDER.get(x["residual_rating"], 9),
        x["category"],
        x["key"],
    ))
    return summary


def main():
    parser = argparse.ArgumentParser(description="Aggregate risk assessment data for Board paper")
    parser.add_argument("--work-dir", required=True, help="RR work directory (e.g., ~/rr-work)")
    parser.add_argument("--quarter", required=True, choices=["Q1", "Q2", "Q3", "Q4"], help="Quarter")
    parser.add_argument("--year", type=int, default=datetime.now().year, help="Year (default: current)")
    args = parser.parse_args()

    work_dir = Path(os.path.expanduser(args.work_dir))
    individual_dir = work_dir / "individual"

    if not individual_dir.exists():
        print(json.dumps({"error": f"Directory not found: {individual_dir}"}), file=sys.stderr)
        sys.exit(1)

    assessment_files = list(individual_dir.glob("RR-*.json"))
    if not assessment_files:
        print(json.dumps({"error": f"No assessment files in {individual_dir}"}), file=sys.stderr)
        sys.exit(1)

    print(f"Loading {len(assessment_files)} assessment files...", file=sys.stderr)
    assessments, load_errors = load_assessments(individual_dir)

    if load_errors:
        print(f"Warnings: {len(load_errors)} files had issues:", file=sys.stderr)
        for e in load_errors[:10]:
            print(f"  - {e}", file=sys.stderr)

    print(f"Successfully loaded {len(assessments)} assessments", file=sys.stderr)

    # Find assessment date from first assessment
    assessment_date = ""
    if assessments:
        assessment_date = assessments[0].get("metadata", {}).get("assessment_date", "")

    # Compute all statistics
    inherent_dist, residual_dist = compute_rating_distributions(assessments)
    heatmaps = compute_heatmaps(assessments)
    categories = compute_category_breakdown(assessments)
    critical_high = extract_critical_high_risks(assessments)
    control_analysis = compute_control_analysis(assessments)
    rec_analysis = compute_recommendation_analysis(assessments)
    all_risks = compute_all_risks_summary(assessments)

    # Build output
    output = {
        "metadata": {
            "generated": datetime.now(timezone.utc).isoformat(),
            "quarter": args.quarter,
            "year": args.year,
            "assessment_date": assessment_date,
            "total_risks": len(assessment_files),
            "total_assessed": len(assessments),
            "load_errors": len(load_errors),
            "source_dir": str(individual_dir),
        },
        "rating_distributions": {
            "inherent": inherent_dist,
            "residual": residual_dist,
        },
        "heatmaps": heatmaps,
        "categories": categories,
        "critical_high_residual_risks": critical_high,
        "control_analysis": control_analysis,
        "recommendation_analysis": rec_analysis,
        "all_risks_summary": all_risks,
    }

    output_path = work_dir / "board-statistics.json"
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"Statistics written to {output_path}", file=sys.stderr)
    print(f"  Risks: {len(assessments)}", file=sys.stderr)
    print(f"  Critical (residual): {residual_dist.get('Critical', 0)}", file=sys.stderr)
    print(f"  High (residual): {residual_dist.get('High', 0)}", file=sys.stderr)
    print(f"  Controls: {control_analysis['total_controls']}", file=sys.stderr)
    print(f"  Recommendations: {rec_analysis['total_recommendations']}", file=sys.stderr)
    print(f"  Critical/High risks for deep-dive: {len(critical_high)}", file=sys.stderr)

    # Output path to stdout for caller
    print(str(output_path))


if __name__ == "__main__":
    main()
