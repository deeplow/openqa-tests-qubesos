from github_reporting import OpenQA, JobData, TestFailure
from argparse import ArgumentParser
import textwrap
from fnmatch import fnmatch

HISTORY_LEN = 200
Q_VERSION = "4.1"
FLAVOR = "pull-requests"

def print_tests_failures(test_suites, test_name, test_title):
    """
    Compares failures across test suites from the same job
    """

    print("Summary:")
    print("\tLooking for failures of test {}/{}".format(test_name,
                                                        test_title))
    print("\tacross test suites: {}".format(str(test_suites)))
    print("\ton the last {} failed tests".format(HISTORY_LEN))

    jobs_ids = {}
    prev_job_count = 0

    for test_suite in test_suites:
        jobs_ids[test_suite] = \
            OpenQA.get_latest_job_ids(test_suite, version=Q_VERSION,
                                      n=HISTORY_LEN, result="failed",
                                      flavor=FLAVOR)
        if prev_job_count and jobs_ids[test_suite] != prev_job_count:
            print("ERROR: test suites with different history lengths\
                are currently not supported")
            exit(1)
        else:
            prev_job_count = len(jobs_ids[test_suite])

    for (i, _) in enumerate(jobs_ids):
        parent_job_id = 0

        for test_suite in test_suites:
            job = JobData(jobs_ids[test_suite][i])

            if parent_job_id and job.get_job_parent_id() != parent_job_id:
                print("ERROR: tests don't have same parent")
                exit(1)
            else:
                parent_job_id = job.get_job_parent_id()

            print("Test suite: {}".format(test_suite))
            print_test_failures(job, test_name, test_title)
            print("\n------\n")

def print_test_failure(job, test_suite, test_name, test_title):
    """
    Prints the failures of a particular test pattern
    """

    result = job.get_results()
    test_failures = result[test_suite]

    print("\n## Job {} (flavor '{}' from {})".format(job.job_id,
                                                    job.get_job_flavor(),
                                                    job.get_job_start_time()))

    for test_failure in test_failures:
        if fnmatch(test_failure.name, test_name):
            if fnmatch(test_failure.title, test_title):

                if test_title != test_failure.title: # wildcard title
                    print("\n### {}".format(test_failure.title))

                print("```python")
                print(test_failure)
                print("```")

def main():
    parser = ArgumentParser(
        description="Look for unstable tests")

    parser.add_argument(
        "--suites",
        help="comma-separated list of test suites"
             "(e.g.: system_tests_network,system_tests_network_ipv6")

    parser.add_argument(
        "--test",
        help="Test Case with wildcard support"
             "(e.g.: TC_00_Direct_*/test_000_version)")

    args = parser.parse_args()

    try:
        (test_name, test_title) = args.test.split('/')
    except ValueError:
        test_name = args.test
        test_title = "*"

    if args.suites:
        compare_test_suites(args.suites.split(","), test_name, test_title)

    if args.test:
        print_tests_failures(args.suites, test_name, test_title)

if __name__ == '__main__':
    main()
