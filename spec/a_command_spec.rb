# frozen_string_literal: true

RSpec.describe ACommand do
  context "Methods" do
    let(:command) {
      Class.new(ACommand::Base) do
        step :simple_step

        def simple_step(ctx, is_success:, **)
          is_success
        end
      end
    }

    it "Should return success if step is succeed" do
      res = command.(is_success: true)
      expect(res.success?).to eq true
    end

    it "Should return failure if step is failed" do
      res = command.(is_success: false)
      expect(res.success?).to eq false
    end
  end

  context "Procs" do
    let(:command) {
      Class.new(ACommand::Base) do
        step ->(ctx){ctx[:is_success]}
      end
    }

    it "Should return success if step is succeed" do
      res = command.(is_success: true)
      expect(res.success?).to eq true
    end

    it "Should return failure if step is failed" do
      res = command.(is_success: false)
      expect(res.success?).to eq false
    end
  end

  context "Subprocesses" do
    let(:command) {
      sub = Class.new(ACommand::Base) do
        step ->(ctx){ctx[:is_success]}
      end

      Class.new(ACommand::Base) do
        step Subprocess(sub)
      end
    }

    it "Should return success if step is succeed" do
      res = command.(is_success: true)
      expect(res.success?).to eq true
    end

    it "Should return failure if step is failed" do
      res = command.(is_success: false)
      expect(res.success?).to eq false
    end
  end

  context "Wrapping" do
    let(:command) {
      wrapping_entity = Class.new do
        class << self
          def call(ctx, block)
            ctx[:start_wrap] = true
            block.call
            ctx[:end_wrap] = true
          end
        end
      end

      Class.new(ACommand::Base) do
        step Wrap(wrapping_entity) {
          step ->(ctx){ctx[:inside_wrap] = true; ctx[:is_success]}
        }
      end
    }

    it "Should do actions before, inside and after wrap" do
      res = command.(is_success: true)
      expect(res.success?).to eq true
      expect(res[:start_wrap]).to eq true
      expect(res[:end_wrap]).to eq true
      expect(res[:inside_wrap]).to eq true
    end

    it "Should return failure if it failed inside wrap" do
      res = command.(is_success: false)
      expect(res.success?).to eq false
    end
  end

  context "Fail" do
    let(:command) {
      sub = Class.new(ACommand::Base) do
        step ->(ctx){ctx[:is_success]}
      end

      Class.new(ACommand::Base) do
        step Subprocess(sub)
        fail ->(ctx){ctx[:error_one] = true}
        fail ->(ctx){ctx[:error_two] = true}
      end
    }

    it "Should process first fail step" do
      res = command.(is_success: false)
      expect(res[:error_one]).to eq true
    end

    it "Should not process second fail step" do
      res = command.(is_success: false)
      expect(res[:error_two]).not_to eq true
    end
  end

  context "Pass" do
    let(:command) {
      sub = Class.new(ACommand::Base) do
        step ->(ctx){ctx[:subprocess] = true; false}
      end

      Class.new(ACommand::Base) do
        pass ->(ctx){ctx[:proc] = true; false}
        pass Subprocess(sub)
        pass :simple_method
        step ->(ctx){true}

        def simple_method(ctx, **)
          ctx[:method] = true
          failure
        end
      end
    }

    it "Should pass procs, subprocesses and methods" do
      res = command.()
      expect(res.success?).to eq true
      expect(res[:proc]).to eq true
      expect(res[:subprocess]).to eq true
      expect(res[:method]).to eq true
    end
  end

  context "Empty commands" do
    let(:command) {
      Class.new(ACommand::Base)
    }

    it "Should raise an exception" do
      expect { command.() }.to raise_error(NotImplementedError)
    end
  end

  context "Pass Fast" do
    let(:command) {
      Class.new(ACommand::Base) do
        step :success_method
        step ->(ctx){ACommand::PassFast}
        fail ->(ctx){ctx[:fail_method] = true}
        step ->(ctx){ctx[:second_success_method] = true}

        def success_method(ctx, **)
          ctx[:success_method] = true
        end
      end
    }

    it "Should pass fast" do
      res = command.()
      expect(res.success?).to eq true
      expect(res[:success_method]).to eq true
      expect(res[:fail_method]).to eq nil
      expect(res[:second_success_method]).to eq nil
    end
  end

  context "Pass Fast (Subcommand)" do
    let(:command) {
      sub = Class.new(ACommand::Base) do
        step ->(ctx){ACommand::PassFast}
      end

      Class.new(ACommand::Base) do
        step Subprocess(sub)
        step :success_method
        fail ->(ctx){ctx[:fail_method] = true}

        def success_method(ctx, **)
          ctx[:success_method] = true
        end
      end
    }

    it "Should pass fast from subcommand" do
      res = command.()
      expect(res.success?).to eq true
      expect(res[:success_method]).to eq nil
      expect(res[:fail_method]).to eq nil
    end
  end

  context "Pass Fast (Wrapped)" do
    let(:command) {
      wrapping_entity = Class.new do
        class << self
          def call(ctx, block)
            ctx[:start_wrap] = true
            block.call
            ctx[:end_wrap] = true
          end
        end
      end

      Class.new(ACommand::Base) do
        step Wrap(wrapping_entity) {
          step ->(ctx){ACommand::PassFast}
        }
        step ->(ctx){ctx[:after_wrap] = true}
      end
    }

    it "Should pass fast from wrapped" do
      res = command.()
      expect(res.success?).to eq true
      expect(res[:start_wrap]).to eq true
      expect(res[:end_wrap]).to eq true
      expect(res[:after_wrap]).to eq nil
    end
  end

  context "Empty commands" do
    let(:command) {
      Class.new(ACommand::Base)
    }

    it "Should raise an exception" do
      expect { command.() }.to raise_error(NotImplementedError)
    end
  end

  context "Perform (alternative syntax)" do
    let(:command) {
      Class.new(ACommand::Base) do
        def perform
          ctx[:is_success] ? success : failure
        end
      end
    }

    it "Should work with success (alternative syntax)" do
      res = command.(is_success: true)
      expect(res.success?).to eq true
    end

    it "Should work with failure (alternative syntax)" do
      res = command.(is_success: false)
      expect(res.success?).to eq false
    end
  end
end
