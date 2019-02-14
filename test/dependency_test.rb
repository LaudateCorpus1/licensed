# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Dependency do
  let(:error) { nil }

  def mkproject(&block)
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        yield Licensed::Dependency.new(name: "test", version: "1.0", path: dir, errors: [error])
      end
    end
  end

  describe "initialize" do
    it "raises an error if the path argument is not an absolute path" do
      assert_raises ArgumentError do
        Licensed::Dependency.new(name: "test", version: "1.0", path: ".")
      end
    end

    describe "with an error" do
      it "sets an error if path is nil or empty" do
        dep = Licensed::Dependency.new(name: "test", version: "1.0", path: "")
        assert_includes dep.errors, "dependency path not found"

        dep = Licensed::Dependency.new(name: "test", version: "1.0", path: nil)
        assert_includes dep.errors, "dependency path not found"
      end
    end
  end

  describe "record" do
    describe "with a dependency error" do
      let(:error) { "error" }

      it "returns nil" do
        mkproject { |dep| assert_nil dep.record }
      end
    end

    it "returns a Licensed::DependencyRecord object with dependency data" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "AUTHORS", "author"
        assert_equal "mit", dependency.record["license"]
        assert_equal "test", dependency.record["name"]
        assert_equal "1.0", dependency.version
        assert_includes dependency.record.licenses,
                        { "sources" => "LICENSE", "text" => Licensee::License.find("mit").text }
        assert_includes dependency.record.notices,
                        { "sources" => "AUTHORS", "text" => "author" }
      end
    end

    it "prefers a name given via metadata over the `name` kwarg" do
      dep = Licensed::Dependency.new(name: "name", version: "1.0", path: Dir.pwd, metadata: { "name" => "meta_name" })
      assert_equal "meta_name", dep.record["name"]
    end
  end

  describe "license_key" do
    describe "with a dependency error" do
      let(:error) { "error" }

      it "returns none" do
        mkproject { |dependency| assert_equal "none", dependency.license_key }
      end
    end

    it "gets license from license file" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        assert_equal "mit", dependency.license_key
      end
    end

    it "gets license from package manager" do
      mkproject do |dependency|
        File.write "project.gemspec", "s.license = 'mit'"
        assert_equal "mit", dependency.license_key
      end
    end

    it "gets license from readme" do
      mkproject do |dependency|
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_equal "mit", dependency.license_key
      end
    end

    it "package manager does not override if LICENSE file is other" do
      mkproject do |dependency|
        File.write "LICENSE.md", "See project.gemspec"
        File.write "project.gemspec", "s.license = 'mit'"
        assert_equal "other", dependency.license_key
      end
    end

    it "gets license from README if package manager has no license assertion" do
      mkproject do |dependency|
        File.write "project.gemspec", "foo"
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_equal "mit", dependency.license_key
      end
    end

    it "gets license from multiple license files" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", Licensee::License.find("bsd-3-clause").text

        assert_equal "other", dependency.license_key
      end
    end

    it "gets license contents from multiple sources" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "README.md", "# License\n" + Licensee::License.find("bsd-3-clause").text
        File.write "project.gemspec", "s.license = 'mit'"

        assert_equal "other", dependency.license_key
      end
    end

    it "sets license to other if undetected" do
      mkproject do |dependency|
        File.write "LICENSE", "some unknown license"
        assert_equal "other", dependency.license_key
      end
    end

    it "sets license to none if no license found" do
      mkproject do |dependency|
        assert_equal "none", dependency.license_key
      end
    end
  end

  describe "license_contents" do
    describe "with a dependency error" do
      let(:error) { "error" }

      it "returns an empty list" do
        mkproject { |dependency| assert_empty dependency.license_contents }
      end
    end

    it "gets license content from license file" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE", "text" => Licensee::License.find("mit").text }
      end
    end

    it "does not get license content from package manager file" do
      mkproject do |dependency|
        File.write "project.gemspec", "s.license = 'mit'"
        assert_empty dependency.license_contents
      end
    end

    it "gets license from readme" do
      mkproject do |dependency|
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_includes dependency.license_contents,
                        { "sources" => "README.md", "text" => Licensee::License.find("mit").text.rstrip }
      end
    end

    it "gets license from README if package manager has no license assertion" do
      mkproject do |dependency|
        File.write "project.gemspec", "foo"
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_includes dependency.license_contents,
                        { "sources" => "README.md", "text" => Licensee::License.find("mit").text.rstrip }
      end
    end

    it "gets license content from multiple license files" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", Licensee::License.find("bsd-3-clause").text

        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE", "text" => Licensee::License.find("mit").text }
        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE.md", "text" => Licensee::License.find("bsd-3-clause").text }
      end
    end

    it "gets license content from multiple sources" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "README.md", "# License\n" + Licensee::License.find("bsd-3-clause").text

        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE", "text" => Licensee::License.find("mit").text }
        assert_includes dependency.license_contents,
                        { "sources" => "README.md", "text" => Licensee::License.find("bsd-3-clause").text.rstrip }
      end
    end

    it "finds license content outside of the dependency path" do
      Dir.mktmpdir do |dir|
        Dir.chdir dir do
          File.write "LICENSE", "license"

          Dir.mkdir "dependency"
          Dir.chdir "dependency" do
            dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd, search_root: File.expand_path(".."))
            source = Pathname.new(dir).basename.join("LICENSE").to_path
            assert_includes dep.license_contents,
                            { "sources" => source, "text" => "license" }
          end
        end
      end
    end

    it "attributes the same content to multiple sources" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", Licensee::License.find("mit").text

        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE, LICENSE.md", "text" => Licensee::License.find("mit").text }
      end
    end
  end

  describe "notice_contents" do
    describe "with a dependency error" do
      let(:error) { "error" }

      it "returns an empty list" do
        mkproject { |dependency| assert_empty dependency.notice_contents }
      end
    end

    it "extracts legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", "authors"
        File.write "NOTICE", "notice"
        File.write "LEGAL", "legal"

        assert_includes dependency.notice_contents,
                        { "sources" => "AUTHORS", "text" => "authors" }
        assert_includes dependency.notice_contents,
                        { "sources" => "NOTICE", "text" => "notice" }
        assert_includes dependency.notice_contents,
                        { "sources" => "LEGAL", "text" => "legal" }
      end
    end

    it "does not extract empty legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", ""
        File.write "NOTICE", ""
        File.write "LEGAL", "legal"

        refute_includes dependency.notice_contents,
                        { "sources" => "AUTHORS", "text" => "authors" }
        refute_includes dependency.notice_contents,
                        { "sources" => "NOTICE", "text" => "notice" }
        assert_includes dependency.notice_contents,
                        { "sources" => "LEGAL", "text" => "legal" }
      end
    end
  end

  describe "error" do
    it "returns true if a dependency has an error" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd, errors: ["error"])
      assert dep.errors?
    end

    it "returns false if a dependency does not have an error" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd)
      refute dep.errors?
    end
  end
end
