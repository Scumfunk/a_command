# frozen_string_literal: true

module ACommand
  class Base
    attr_reader :ctx
    attr_accessor :fail_mode, :failed_step, :pass_fast_mode

    def initialize(ctx)
      @ctx = ctx
      @fail_mode = false
      @pass_fast_mode = false
    end

    def perform
      raise NotImplementedError
    end

    def success
      Success.new(@ctx)
    end

    def failure
      Failure.new(@ctx, @failed_step)
    end

    def pass_fast
      PassFast.new(@ctx)
    end

    class << self
      attr_accessor :steps

      def step(action, &block)
        add_step(action, :step, &block)
      end

      def pass(action, &block)
        add_step(action, :pass, &block)
      end

      def fail(action, &block)
        add_step(action, :fail, &block)
      end

      def wrap(action, &block)
        add_step(action, :wrap, &block)
      end

      def Subprocess(command)
        command
      end

      def Nested(command, &block)
        StepWrapper.new(command, :nested, &block)
      end

      def Wrap(command, &block)
        StepWrapper.new(command, :wrap, &block)
      end

      def call(context = nil, **args)
        ctx = context || build_context(**args)
        if @steps && @steps.any?
          inst = new(ctx)
          res = nil
          @steps.each do |action|
            if inst.pass_fast_mode
              next
            elsif inst.fail_mode
              if action.kind == :fail
                process_step(action, inst)
                return inst.failure
              else
                next
              end
            else
              res = process_step(action, inst)
              if !res || res.is_a?(Failure)
                inst.failed_step = action
                inst.fail_mode = true
              end
              if !inst.fail_mode && (res == PassFast || res.is_a?(PassFast))
                inst.pass_fast_mode = true
              end
            end
          end
          if !res || res.is_a?(Failure)
            return inst.failure
          elsif res == PassFast
            return inst.pass_fast
          else
            return inst.success
          end
        else
          res = new(ctx).perform
          if res.is_a?(Success) || res.is_a?(Failure)
            return res
          else
            return Failure.new(ctx)
          end
        end
      end

      def process_step(step, inst)
        res = nil
        if step.kind == :nested
          step.action = inst.send(step.action, inst.ctx, **inst.ctx.data)
        end
        case step.action.class.to_s
        when 'Symbol', 'String'
          res = inst.send(step.action, inst.ctx, **inst.ctx.data)
        else
          if step.block == nil
            res = step.action.(inst.ctx)
          else
            command = Class.new(self, &step.block)
            step.action.(inst.ctx, ->{res = command.call(inst.ctx)})
          end
        end
        return inst.success if step.kind == :pass
        res
      end

      private def build_context(**args)
        @ctx = Context.new(**args)
      end

      private def add_step(action, kind=:step, &block)
        @steps = [] unless @steps
        if action.is_a? StepWrapper
          @steps << action
        else
          @steps << StepWrapper.new(action, kind, &block)
        end
      end

    end
  end

  class Context
    attr_reader :data

    def initialize(**params)
      @data = params
    end

    def [](x)
      @data[x]
    end

    def []=(x, y)
      @data[x] = y
    end
  end

  class Result
    attr_reader :failed_step, :ctx

    def initialize(ctx, failed_step = nil)
      @ctx = ctx
      @failed_step = failed_step
    end

    def success?
      is_a?(Success)
    end

    def failure?
      is_a?(Failure)
    end

    def [](x)
      ctx[x]
    end
  end

  class Success < Result; end

  class Failure < Result; end
  
  class PassFast < Success; end

  class StepWrapper
    attr_accessor :kind, :action, :block

    def initialize(action, kind=:step, &block)
      @kind = kind
      @action = action
      @block = block
    end
  end
end