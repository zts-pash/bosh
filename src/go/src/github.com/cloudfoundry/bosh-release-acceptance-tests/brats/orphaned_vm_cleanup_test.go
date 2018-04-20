package brats_test

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

type scheduledJob struct {
	Command  string `json:"command"`
	Schedule string `json:"schedule"`
}

var _ = Describe("Orphaning VMs", func() {
	BeforeEach(func() {
		startInnerBosh()

		tmpFile, err := ioutil.TempFile("", "pre-change-speedy-schedule-config.yml")
		if err != nil {
			Expect(err).ToNot(HaveOccurred())
		}

		defer os.Remove(tmpFile.Name())

		session := outerBosh("-d", "bosh", "scp", "bosh:/var/vcap/jobs/director/config/director.yml", tmpFile.Name())
		Eventually(session, time.Minute).Should(gexec.Exit(0))

		configBs, err := ioutil.ReadFile(tmpFile.Name())
		Expect(err).ToNot(HaveOccurred())

		var c map[string]interface{}
		err = json.Unmarshal(configBs, &c)
		Expect(err).ToNot(HaveOccurred())

		singleJob := scheduledJob{Command: "ScheduledOrphanedVMCleanup", Schedule: "*/5 * * * * * UTC"}
		c["scheduled_jobs"] = []scheduledJob{singleJob}

		resultBs, err := json.Marshal(c)
		Expect(err).ToNot(HaveOccurred())

		tmpFile, err = ioutil.TempFile("", "speedy-schedule-config.yml")
		if err != nil {
			Expect(err).ToNot(HaveOccurred())
		}

		defer os.Remove(tmpFile.Name())

		if _, err := tmpFile.Write(resultBs); err != nil {
			Expect(err).ToNot(HaveOccurred())
		}
		if err := tmpFile.Close(); err != nil {
			Expect(err).ToNot(HaveOccurred())
		}

		session = outerBosh("-d", "bosh", "scp", tmpFile.Name(), "bosh:/tmp/director.yml")
		Eventually(session, time.Minute).Should(gexec.Exit(0))

		session = outerBosh("-d", "bosh", "ssh", "-c", "sudo mv -f /tmp/director.yml /var/vcap/jobs/director/config/director.yml")
		Eventually(session, time.Minute).Should(gexec.Exit(0))

		// session = outerBosh("-d", "bosh", "ssh", "bosh", "-c", "sudo cat /var/vcap/jobs/director/config/director.yml")
		// Eventually(session, time.Minute).Should(gexec.Exit(0))
		// Expect(string(session.Out.Contents())).To(BeNil())
		// echo foo | ssh -i jumpbox.key  jumpbox@192.168.50.6 'sudo cat > /tmp/foo'

	})

	// AfterEach(func() {
	// 	stopInnerBosh()
	// })

	FIt("schedules a job that deletes orphaned VMs", func() {
		time.Sleep(1000)
		// cswManifestPath := assetPath("create-swap-delete-manifest.yml")

		// content, err := ioutil.ReadFile(configPath)
		// Expect(err).NotTo(HaveOccurred())
		// Expect(string(content)).To(ContainSubstring(redactable))

		// session = outerBosh("-d", "bosh", "ssh", "bosh", "-c", "sudo cat /var/vcap/sys/log/director/*")
		// Eventually(session, time.Minute).Should(gexec.Exit(0))
		// Expect(string(session.Out.Contents())).To(ContainSubstring("INSERT INTO \"configs\" <redacted>"))
		// Expect(string(session.Out.Contents())).NotTo(ContainSubstring(redactable))
		// Expect(string(session.Out.Contents())).NotTo(ContainSubstring("SELECT NULL"))

	})
})
